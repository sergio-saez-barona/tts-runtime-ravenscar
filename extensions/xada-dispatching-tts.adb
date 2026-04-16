------------------------------------------------------------
--
--  GNAT RUN-TIME EXTENSIONS
--
--  XADA . DISPATCHING . TIME-TRIGGERED SCHEDULING
--
--  @file x-distts.adb / xada-dispatching-tts.adb
--
--  @package XAda.Dispatching.TTS (BODY)
--
--  @author Jorge Real <jorge@disca.upv.es>
--  @author Sergio Saez <ssaez@disca.upv.es>
--
------------------------------------------------------------

with Ada.Task_Identification;      use Ada.Task_Identification;
with Ada.Synchronous_Task_Control; use Ada.Synchronous_Task_Control;
with Ada.Real_Time;                use Ada.Real_Time;
with Ada.Real_Time.Timing_Events;  use Ada.Real_Time.Timing_Events;

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Tags;    use Ada.Tags;

with Ada.Exceptions; use Ada.Exceptions;

pragma Warnings (Off);
with System.BB.Threads;  use System.BB.Threads;
with System.BB.Time;
with System.Tasking;     use System.Tasking;
with System.TTS_Support; use System.TTS_Support;
pragma Warnings (On);

--------------------------
-- XAda.Dispatching.TTS --
--------------------------

package body XAda.Dispatching.TTS is

   --  Conservative bound of measured overhead on a STM32F4 Discovery
   --  Since release delay is very predictable in this platform (between
   --  23 and 24 us) we charge that overhead at the end of the slot, by
   --  effectively advancing the slot start time by the Overhead time.
   --  This reduces the release jitter even further for TT tasks, to about 3 us
   Time_Offset : constant Time_Span := Microseconds (15);
   --  Time needed to program the next alarm in the hardware timer, measured in the platform
   Alarm_Delay : constant Time_Span := Microseconds (5);
   Overhead    : constant Time_Span := Time_Offset + Alarm_Delay;

   --  Current Criticality Level
   Current_Criticality_Level : Criticality_Levels := Criticality_Levels'First
   with Atomic;

   Plan_Start : Time := Time_First
   with Volatile;

   --  Type of event to be programmed
   type Scheduling_Point_Type is
     (None, Hold_Point, End_Of_Work_Point, Next_Slot_Point);

   --------------------------------
   --  Control Block Structures  --
   --------------------------------

   --  Run time TT work info
   type Work_Control_Block is record
      Has_Completed : Boolean := True;      --  TT part has completed
      Is_Waiting    : Boolean := False;     --  Task is waiting for release
      Is_Sliced     : Boolean := False;     --  Task is in a sliced sequence

      Is_Sync : Boolean := False;     --  Expected Task is ET

      --  Indicates how many slots have been skipped
      Skip_Count : Natural := 0;

      Work_Thread_Id : Thread_Id := Null_Thread_Id;  --  Underlying thread id

      Last_Release      : Time := Time_Last;  --  Time of last release
      Last_Slot_Release : Time := Time_Last;  --  Time of last slot release

      --  Overrun management
      Event           : Overrun_Event;
      Overrun_Handler : Timing_Event_Handler := null; --  Overrun handler

      --  Activable Work ID
      Is_Active                : Boolean := True;
      Active_Criticality_Level : Criticality_Levels :=
        Criticality_Levels'First;
   end record;
   type Work_Control_Block_Access is access all Work_Control_Block;

   --  Array of Work_Control_Blocks
   WCB : array (TT_Work_Id) of aliased Work_Control_Block;

   --  Array of suspension objects for TT tasks to wait for activation
   Release_Point : array (TT_Work_Id) of Suspension_Object;

   --------------------
   --  TTS_Put_Line  --
   --------------------

   function TT_Timestamp (T : Time := Clock) return String is
      Offset : Time_Span := T - Plan_Start;
   begin
      return To_Duration (Offset)'Image;
   end TT_Timestamp;

   function TT_Time (T : Time := Clock) return String is
      Offset : Time_Span := T - Time_First;
   begin
      return To_Duration (Offset)'Image;
   end TT_Time;

   procedure TTS_Put_Line (Item : in String) is
   begin
      if Debug then
         Put_Line (Item);
      end if;
   end TTS_Put_Line;

   procedure TTS_Debug (Item : in String) is
   begin
      if Debug then
         Put_Line (TT_Timestamp & " > " & Item);
      end if;
   end TTS_Debug;

   ------------------------------
   -- Check_Work_Control_Block --
   ------------------------------

   procedure Check_Work_Control_Block
     (Current_Slot      : Any_Time_Slot;
      Caller            : String;
      Current_Work_Slot : out Any_Work_Slot;
      Current_WCB       : out Work_Control_Block_Access) is
   begin
      if Current_Slot.all not in Work_Slot'Class then
         TTS_Debug ("raise Program_Error");
         raise Program_Error with (Caller & " called for a non-TT task");
      end if;

      Current_Work_Slot := Any_Work_Slot (Current_Slot);
      Current_WCB := WCB (Current_Work_SLot.Work_Id)'access;

      -- If the slot is a Continuation with zero padding,
      --  then the current task has to be the owner of the slot,
      --  otherwise it is a misuse of the API.
      if Current_Work_Slot.Work_Type = Continuation
        and then
          Current_Work_Slot.Padding_Duration
            (Current_WCB.Active_Criticality_Level)
          = Time_Span_Zero
        and then Current_WCB.Work_Thread_Id /= Thread_Self
      then
         TTS_Debug ("raise Program_Error");
         raise Program_Error
           with
             (Caller
              & " called from Work_Id different to "
              & Any_Work_Slot (Current_Slot).Work_Id'Image);
      end if;

      if Current_Work_Slot.Work_Type = Sync or Current_WCB.Has_Completed then
         TTS_Debug ("raise Program_Error");
         raise Program_Error with (Caller & " called for a non-TT task");
      end if;

   end Check_Work_Control_Block;

   ------------------
   --  Slot Types  --
   ------------------

   -- It returns the Work duration for a given CL.
   function Work_Duration
     (S : in Work_Slot; CL : in Criticality_Levels := Criticality_Levels'First)
      return Time_Span
   is (if S.Work_Type /= Sync then S.Work_Sizes (CL) else Time_Span_Last);

   -- It returns the Padding duration for a given CL.
   function Padding_Duration
     (S : in Work_Slot; CL : in Criticality_Levels := Criticality_Levels'First)
      return Time_Span
   is (if S.Work_Type /= Sync then S.Padding_Sizes (CL) else Time_Span_Zero);

   ----------------
   --  Set_Plan  --
   ----------------

   procedure Set_Plan
     (TTP : Time_Triggered_Plan_Access; At_Time : Time := End_Of_MC_Slot) is
   begin
      if In_Protected_Action (Thread_Self) then
         --  TODO
         null;
      else
         Time_Triggered_Scheduler.Set_Plan (TTP, At_Time);
      end if;
   end Set_Plan;

   --------------------------
   --  Wait_For_Activation --
   --------------------------
   procedure Wait_For_Activation
     (Work_Id : TT_Work_Id; When_Was_Released : out Time) is
   begin
      TTS_Debug ("Wait_For_Activation");

      --  Raise own priority, before getting blocked. This is to recover the TT
      --  priority when the calling task has previuosly called Leave_TT_Level
      Set_Priority (TT_Priority);

      --  Inform the TT scheduler the task is going to wait for activation
      Time_Triggered_Scheduler.Process_Activation
        (Work_Id => Work_Id, Is_Sync => False, Is_Skipped => False);

      --  Suspend until the next slot for Work_Id starts
      Suspend_Until_True (Release_Point (Work_Id));

      --  Scheduler updated Last_Release when it released the worker task
      When_Was_Released := WCB (Work_Id).Last_Release;

   end Wait_For_Activation;

   ----------------------
   --  Skip_Activation --
   ----------------------
   procedure Skip_Activation (Work_Id : TT_Work_Id) is
   begin
      TTS_Debug ("Skip_Activation");
      --  Inform the TT scheduler the task is going to skip next activation
      Time_Triggered_Scheduler.Process_Activation
        (Work_Id => Work_Id, Is_Sync => False, Is_Skipped => True);

   end Skip_Activation;

   ---------------------
   -- Continue_Sliced --
   ---------------------

   procedure Continue_Sliced is
   begin
      TTS_Debug ("Continue_Sliced");
      Time_Triggered_Scheduler.Continue_Sliced;
   end Continue_Sliced;

   --------------------
   -- Leave_TT_Level --
   --------------------

   procedure Leave_TT_Level is
   begin
      TTS_Debug ("Leave_TT_Level");
      Time_Triggered_Scheduler.Leave_TT_Level;
   end Leave_TT_Level;

   --------------------
   --  Wait_For_Sync --
   --------------------

   procedure Wait_For_Sync (Work_Id : TT_Work_Id; When_Was_Released : out Time)
   is
   begin
      TTS_Debug ("Wait_For_Sync");
      --  Inform the TT scheduler the ET task has reached the sync point
      Time_Triggered_Scheduler.Process_Activation
        (Work_Id => Work_Id, Is_Sync => True, Is_Skipped => False);

      --  Suspend until the next sync slot for Work_Id starts
      --  If the sync point has been already reached in the plan,
      --    the SO is open and the ET task will not suspend
      Suspend_Until_True (Release_Point (Work_Id));

      --  Scheduler updated Last_Release when it released the worker task
      When_Was_Released := WCB (Work_Id).Last_Release;

   end Wait_For_Sync;

   ----------------
   --  Skip_Sync --
   ----------------
   procedure Skip_Sync (Work_Id : TT_Work_Id) is
   begin
      TTS_Debug ("Skip_Sync");
      --  Inform the TT scheduler the task is going to wait for activation
      Time_Triggered_Scheduler.Process_Activation
        (Work_Id => Work_Id, Is_Sync => True, Is_Skipped => True);
   end Skip_Sync;

   ----------------------
   -- Get_Current_Slot --
   ----------------------

   function Get_Current_Slot return Any_Time_Slot is
   begin
      return Time_Triggered_Scheduler.Get_Current_Slot;
   end Get_Current_Slot;

   ----------------------------
   -- Get_First_Plan_Release --
   ----------------------------

   function Get_First_Plan_Release return Ada.Real_Time.Time is
   begin
      return Time_Triggered_Scheduler.Get_First_Plan_Release;
   end Get_First_Plan_Release;

   ---------------------------
   -- Get_Last_Plan_Release --
   ---------------------------

   function Get_Last_Plan_Release return Ada.Real_Time.Time is
   begin
      return Time_Triggered_Scheduler.Get_Last_Plan_Release;
   end Get_Last_Plan_Release;

   ---------------------------------
   -- Set_Default_Overrun_Handler --
   ---------------------------------

   procedure Set_Default_Overrun_Handler
     (Handler : Ada.Real_Time.Timing_Events.Timing_Event_Handler) is
   begin
      Time_Triggered_Scheduler.Set_Default_Overrun_Handler (Handler);
   end Set_Default_Overrun_Handler;

   ----------------------------------
   -- Set_Specific_Overrun_Handler --
   ----------------------------------

   procedure Set_Specific_Overrun_Handler
     (Work_Id : TT_Work_Id;
      Handler : Ada.Real_Time.Timing_Events.Timing_Event_Handler) is
   begin
      Time_Triggered_Scheduler.Set_Specific_Overrun_Handler (Work_Id, Handler);
   end Set_Specific_Overrun_Handler;

   ----------------------------------
   -- Set_System_Criticality_Level --
   ----------------------------------

   procedure Set_System_Criticality_Level (New_Level : Criticality_Levels) is
   begin
      TTS_Put_Line
        ("## CL change "
         & Current_Criticality_Level'Image
         & " -> "
         & New_Level'Image);
      Current_Criticality_Level := New_Level;
   end Set_System_Criticality_Level;

   ----------------------------------
   -- Get_System_Criticality_Level --
   ----------------------------------

   function Get_System_Criticality_Level return Criticality_Levels is
   begin
      return Current_Criticality_Level;
   end Get_System_Criticality_Level;

   ----------------------------------
   -- Set_Active_Criticality_Level --
   ----------------------------------

   procedure Set_Active_Criticality_Level
     (Work_Id : TT_Work_Id; New_Level : Criticality_Levels) is
   begin
      if WCB (Work_Id).Work_Thread_Id /= Thread_Self then
         raise Program_Error
           with
             ("Running Task does not correspond to Work_Id " & Work_Id'Image);
      end if;

      WCB (Work_Id).Active_Criticality_Level := New_Level;
   end Set_Active_Criticality_Level;

   ----------------------------------
   -- Get_Active_Criticality_Level --
   ----------------------------------

   function Get_Active_Criticality_Level
     (Work_Id : TT_Work_Id) return Criticality_Levels is
   begin
      if WCB (Work_Id).Work_Thread_Id /= Thread_Self then
         raise Program_Error
           with
             ("Running Task does not correspond to Work_Id " & Work_Id'Image);
      end if;

      return WCB (Work_Id).Active_Criticality_Level;
   end Get_Active_Criticality_Level;

   ------------------------------
   -- Time_Triggered_Scheduler --
   ------------------------------

   protected body Time_Triggered_Scheduler is

      --------------
      -- Set_Plan --
      --------------

      procedure Set_Plan (TTP : Time_Triggered_Plan_Access; At_Time : Time) is
         Now : constant Time := Clock;
      begin

         --  Take note of next plan to execute
         Next_Plan := TTP;

         if Next_Plan /= null then
            Next_Mode_Release := At_Time;

            if Current_Plan = null then
               --  If there is no active plan, we assume there is a big mode change slot.
               --  The scheduler will change to the new plan just now, if the specified time is already passed,
               --  or at the end of the mode change slot is specified.
               --  Otherwise, the new plan will be released at the specified time.

               if Next_Mode_Release = End_Of_MC_Slot
                 or else Next_Mode_Release <= Now
               then
                  Change_Plan (Now);
               else
                  Change_Plan (Next_Mode_Release);
               end if;

            elsif Current_Plan (Current_Slot_Index).all
                  in Mode_Change_Slot'Class
            then
               --  Accept Set_Plan requests during a mode change slot (coming
               --  from PB tasks) and enforce the mode change.
               if Next_Mode_Release = End_Of_MC_Slot then
                  Change_Plan (Next_Slot_Release);
               elsif Next_Mode_Release <= Now then
                  Change_Plan (Now);
               elsif Next_Mode_Release <= Next_Slot_Release then
                  Change_Plan (Next_Mode_Release);
               else
                  --  Mode change request remains pending
                  null;
               end if;
            end if;
         end if;

      end Set_Plan;

      ------------------------
      -- Process_Activation --
      ------------------------

      procedure Process_Activation
        (Work_Id : TT_Work_Id; Is_Sync : Boolean; Is_Skipped : Boolean)
      is
         Current_Slot : Any_Time_Slot;
         Current_WCB  : Work_Control_Block_Access;
         Cancelled    : Boolean;
      begin
         --  Register the Work_Id with the first task using it.
         --  Use of the Work_Id by another task breaks the model and causes PE
         if WCB (Work_Id).Work_Thread_Id = Null_Thread_Id then

            --  First time WFA called with this Work_Id -> Register caller
            WCB (Work_Id).Work_Thread_Id := Thread_Self;

         elsif WCB (Work_Id).Work_Thread_Id /= Thread_Self then

            --  Caller was not registered with this Work_Id
            raise Program_Error with ("Work_Id misuse");
         end if;

         if Current_Plan /= null then
            Current_Slot := Current_Plan (Current_Slot_Index);

            if Current_Slot.all in Work_Slot'Class then
               Current_WCB :=
                 WCB (Any_Work_Slot (Current_Slot).Work_Id)'access;

               -- If the invoking thread is the owner of the current Work Slot
               --  then the slot is considered completed.
               if Current_WCB.Work_Thread_Id = Thread_Self
                 and then not Current_WCB.Has_Completed
               then
                  Current_WCB.Has_Completed := True;

                  --  Cancel the Hold and End of Work handlers, if required

                  TTS_Debug ("Cancel_Handler Hold @ Process_Activation");
                  Hold_Event.Cancel_Handler (Cancelled);
                  TTS_Debug
                    ("Cancel_Handler End_of_Work @ Process_Activation");
                  End_Of_Work_Event.Cancel_Handler (Cancelled);

                  --  Set timing event for the next scheduling point
                  TTS_Debug ("Set_Handler Next_Slot @ Process_Activation");
                  Next_Slot_Event.Set_Handler
                    (Next_Slot_Release - Overhead, Next_Slot_Handler_Access);
               end if;
            end if;
         end if;

         if Is_Skipped then
            --  The next work slot is being ignored
            WCB (Work_Id).Skip_Count := WCB (Work_Id).Skip_Count + 1;
         else
            --  The caller is about to be suspended
            WCB (Work_Id).Is_Sync := Is_Sync;
            WCB (Work_Id).Is_Waiting := True;
         end if;

      end Process_Activation;

      ---------------------
      -- Continue_Sliced --
      ---------------------

      procedure Continue_Sliced is
         Current_Slot      : constant Any_Time_Slot :=
           Current_Plan (Current_Slot_Index);
         Current_Work_Slot : Any_Work_Slot;
         Current_WCB       : Work_Control_Block_Access;
         Cancelled         : Boolean;
      begin
         Check_Work_Control_Block
           (Current_Slot, "Continue_Sliced", Current_Work_Slot, Current_WCB);

         Current_WCB.Is_Sliced := True;

         if Current_Work_Slot.Padding_Duration
              (Current_WCB.Active_Criticality_Level)
           > Time_Span_Zero
         then
            TTS_Debug ("Cancel_Handler End_of_Work @ Continue_Sliced");
            End_Of_Work_Event.Cancel_Handler (Cancelled);
            TTS_Debug ("Set_Handler Hold @ Continue_Sliced");
            Hold_Event.Set_Handler
              (Hold_Release - Alarm_Delay, Hold_Handler_Access);
         else
            TTS_Debug ("Set_Handler End_of_Work @ Continue_Sliced");
            End_Of_Work_Event.Set_Handler
              (End_Of_Work_Release - Alarm_Delay, End_Of_Work_Handler_Access);
         end if;

      end Continue_Sliced;

      --------------------
      -- Leave_TT_Level --
      --------------------

      procedure Leave_TT_Level is
         Current_Slot      : constant Any_Time_Slot :=
           Current_Plan (Current_Slot_Index);
         Current_Work_Slot : Any_Work_Slot;
         Current_WCB       : Work_Control_Block_Access;
         Base_Priority     : System.Priority;
         Cancelled         : Boolean;
      begin
         Check_Work_Control_Block
           (Current_Slot, "Leave_TT_Level", Current_Work_Slot, Current_WCB);

         Current_WCB.Has_Completed := True;

         --  Cancel the Hold and End of Work handlers, if required
         TTS_Debug ("Cancel_Handler Hold @ Leave_TT_Level");
         Hold_Event.Cancel_Handler (Cancelled);
         TTS_Debug ("Cancel_Handler End_Of_Work @ Leave_TT_Level");
         End_Of_Work_Event.Cancel_Handler (Cancelled);

         --  Set timing event for the next scheduling point
         TTS_Debug ("Set_Handler Next_Slot @ Leave_TT_Level");
         Next_Slot_Event.Set_Handler
           (Next_Slot_Release - Overhead, Next_Slot_Handler_Access);

         Base_Priority := Current_WCB.Work_Thread_Id.Base_Priority;
         Set_Priority (Base_Priority);

      end Leave_TT_Level;

      -----------------
      -- Change_Plan --
      -----------------

      procedure Change_Plan (At_Time : Time) is
      begin
         Current_Plan := Next_Plan;
         Next_Plan := null;
         --  Setting both Current_ and Next_Slot_Index to 'First is consistent
         --  with the Next Slot TE handler for the first slot of a new plan.
         Current_Slot_Index := Current_Plan.all'First;
         Next_Slot_Index := Current_Plan.all'First;
         Next_Slot_Release := At_Time;
         Plan_Start_Pending := True;
         TTS_Debug ("Set_Handler Next_Slot @ Change_Plan :" & TT_Timestamp);
         Next_Slot_Event.Set_Handler
           (At_Time - Overhead, Next_Slot_Handler_Access);
      end Change_Plan;

      ----------------------------
      -- Get_Last_First_Release --
      ----------------------------

      function Get_First_Plan_Release return Ada.Real_Time.Time is
      begin
         return First_Plan_Release;
      end Get_First_Plan_Release;

      ---------------------------
      -- Get_Last_Plan_Release --
      ---------------------------

      function Get_Last_Plan_Release return Ada.Real_Time.Time is
      begin
         return First_Slot_Release;
      end Get_Last_Plan_Release;

      ----------------------
      -- Get_Current_Slot --
      ----------------------

      function Get_Current_Slot return Any_Time_Slot is
      begin
         return
           (if Current_Plan /= null and then not Plan_Start_Pending
            then Current_Plan (Current_Slot_Index)
            else null);
      end Get_Current_Slot;

      -------------------------
      -- Set_Default_Overrun_Handler --
      -------------------------

      procedure Set_Default_Overrun_Handler
        (Handler : Ada.Real_Time.Timing_Events.Timing_Event_Handler) is
      begin
         System_Overrun_Handler_Access := Handler;
      end Set_Default_Overrun_Handler;

      -------------------------
      -- Set_Specific_Overrun_Handler --
      -------------------------

      procedure Set_Specific_Overrun_Handler
        (Work_Id : TT_Work_Id;
         Handler : Ada.Real_Time.Timing_Events.Timing_Event_Handler) is
      begin
         WCB (Work_Id).Overrun_Handler := Handler;
      end Set_Specific_Overrun_Handler;

      ----------------------
      -- Overrun_Detected --
      ----------------------

      procedure Overrun_Detected
        (Current_Work_Slot : Any_Work_Slot; Time_Of_Event : Time)
      is
         Current_WCB     : Work_Control_Block_Access;
         Overrun_Handler : Timing_Event_Handler := null;
      begin
         TTS_Debug ("Executing Overrun_Detected ... ");
         Current_WCB := WCB (Current_Work_Slot.Work_Id)'access;

         Overrun_Handler :=
           (if Current_WCB.Overrun_Handler /= null
            then Current_WCB.Overrun_Handler
            else System_Overrun_Handler_Access);

         --  Overrun detected
         if Overrun_Handler /= null then
            Current_WCB.Event.Slot := Current_Work_Slot;

            --  Time_Of_Event is used instead of Now since
            --  due to the use of 'Overhead' maybe Now < Clock and then
            --  the handlers bellow are not directly executed after this one

            --  Executes the Overrun handler as soon as possible
            TTS_Debug ("Set_Handler Overrun @ Overrun_Detected");
            Current_WCB.Event.Set_Handler (Time_Of_Event, Overrun_Handler);

            --  Program the Reschedule event to check if the
            --   Work_Duration has changed after the handler execution
            --  ARM12 D.15 20/2
            --   "If several timing events are set for the same time,
            --    they are executed in FIFO order of being set."
            TTS_Debug ("Set_Handler Reschedule @ Overrun_Detected");
            Reschedule_Event.Set_Handler
              (Time_Of_Event, Reschedule_Handler_Access);
         else
            raise Program_Error
              with ("Overrun in TT task " & Current_Work_Slot.Work_Id'Image);
         end if;

      end Overrun_Detected;

      ------------------
      -- Hold_Handler --
      ------------------

      procedure Hold_Handler (Event : in out Timing_Event) is
         pragma Unreferenced (Event);
         Current_Slot      : constant Any_Time_Slot :=
           Current_Plan (Current_Slot_Index);
         Current_Work_Slot : Any_Work_Slot;
         Current_WCB       : Work_Control_Block_Access;
         Current_Thread_Id : Thread_Id;
      begin
         TTS_Debug ("Executing Hold_Handler ... ");

         Check_Work_Control_Block
           (Current_Slot, "Hold handler", Current_Work_Slot, Current_WCB);

         Current_Thread_Id := Current_WCB.Work_Thread_Id;

         --  TODO: Check if this condition is required
         if not Current_WCB.Has_Completed then
            Hold (Current_Thread_Id);

            --  Set timing event for the next scheduling point
            TTS_Debug ("Set_Handler End_of_Work @ Hold_Handler");
            End_Of_Work_Event.Set_Handler
              (End_Of_Work_Release - Alarm_Delay, End_Of_Work_Handler_Access);
         --  Next_Slot handler will be set when this work was finished

         end if;

      end Hold_Handler;

      -------------------------
      -- End_Of_Work_Handler --
      -------------------------

      procedure End_Of_Work_Handler (Event : in out Timing_Event) is
         Current_Slot      : constant Any_Time_Slot :=
           Current_Plan (Current_Slot_Index);
         Current_Work_Slot : Any_Work_Slot;
         Current_WCB       : Work_Control_Block_Access;
         Current_Thread_Id : Thread_Id;
         Now               : Time;
      begin
         TTS_Debug ("Executing End_Of_Work_Handler ... ");

         Check_Work_Control_Block
           (Current_Slot, "EoW handler", Current_Work_Slot, Current_WCB);

         --  This is the current time, according to the plan
         Now := End_Of_Work_Release;

         ----------------------------------
         --  PROCESS ENDING OF WORK SLOT --
         ----------------------------------

         --  Check for overrun in the ending slot, if it is a Work_Slot.
         --  If this happens to be the first slot after a plan change, then
         --  we come from a mode-change slot, so there is no overrun to check,
         --  because it was checked before that mode-change slot

         --  Possible overrun detected, unless task is running sliced.
         --  First check that all is going well
         Current_Thread_Id := Current_WCB.Work_Thread_Id;

         --  Check whether the task is running sliced or this is
         --  a real overrun situation
         if Current_WCB.Is_Sliced then
            if Current_Work_Slot.Padding_Duration
                 (Current_WCB.Active_Criticality_Level)
              > Time_Span_Zero
            then
               if Current_Thread_Id.Hold_Signaled then
                  raise Program_Error
                    with
                      ("Overrun in PA of Sliced TT task "
                       & Current_Work_Slot.Work_Id'Image);
               end if;
               --  In the other case, the thread is supposed already held
               pragma Assert (Current_Thread_Id /= Thread_Self);
            else
               --  Thread_Self is the currently running thread on this CPU.
               --  If this assertion fails, the running TT task is using a
               --  wrong slot, which should never happen
               pragma Assert (Current_Thread_Id = Thread_Self);

               Hold (Current_Thread_Id, True);
               --  Context switch occurs after executing this handler
            end if;

            if (Next_Slot_Release - Time_Offset > Now) then
               --  Set timing event for the next scheduling point
               TTS_Debug ("Set_Handler Next_Slot @ End_of_Work_Handler");
               Next_Slot_Event.Set_Handler
                 (Next_Slot_Release - Overhead, Next_Slot_Handler_Access);
            else
               --  Directly process the new slot event
               TTS_Debug ("Execute_Handler Next_Slot @ End_of_Work_Handler");
               Next_Slot_Handler (Event);
               -- Next_Slot_Event.Set_Handler (Now, Next_Slot_Handler_Access);
            end if;

         else
            Overrun_Detected (Current_Work_Slot, Event.Time_Of_Event);
         end if;

      end End_Of_Work_Handler;

      ------------------------
      -- Reschedule_Handler --
      ------------------------

      procedure Reschedule_Handler (Event : in out Timing_Event) is
         pragma Unreferenced (Event);
         Current_Slot      : constant Any_Time_Slot :=
           Current_Plan (Current_Slot_Index);
         Current_Work_Slot : Any_Work_Slot;
         Current_WCB       : Work_Control_Block_Access;

      begin
         TTS_Debug ("Executing Reschedule_Handler ... ");

         Check_Work_Control_Block
           (Current_Slot, "Resched handler", Current_Work_Slot, Current_WCB);

         Current_WCB.Active_Criticality_Level := Current_Criticality_Level;

         if End_Of_Work_Release
           < Current_WCB.Last_Slot_Release
             + Current_Work_Slot.Work_Duration
                 (Current_WCB.Active_Criticality_Level)
         then

            --  Work duration has been increased, so reprogram the EoW event
            End_Of_Work_Release :=
              Current_WCB.Last_Slot_Release
              + Current_Work_Slot.Work_Duration
                  (Current_WCB.Active_Criticality_Level);
            Next_Slot_Release :=
              Current_WCB.Last_Slot_Release + Current_Work_Slot.Slot_Duration;

            if End_Of_Work_Release > Next_Slot_Release then
               raise Program_Error
                 with
                   ("Work duration is beyond slot duration for Work_Id "
                    & Current_Work_Slot.Work_Id'Image
                    & " Slot Index "
                    & Current_Slot_Index'Image);
            end if;

            --  Reschedule event can only be emitted from an EoW handler
            TTS_Debug ("Set_Handler End_of_Work @ Reschedule_Handler");
            End_Of_Work_Event.Set_Handler
              (End_Of_Work_Release - Alarm_Delay, End_Of_Work_Handler_Access);

            --  An overrun cannot happen during a sliced slot,
            --   so Hold handler does not need to be reconsidered

            --  Just in case, this is the final slot of a sliced sequence
            if Is_Held (Current_WCB.Work_Thread_Id) then
               Continue (Current_WCB.Work_Thread_Id);
            end if;
         else
            raise Program_Error
              with
                ("Overrun in TT task "
                 & Current_Work_Slot.Work_Id'Image
                 & " @ CL "
                 & Current_Criticality_Level'Image);
         end if;

      end Reschedule_Handler;

      -----------------------
      -- Next_Slot_Handler --
      -----------------------

      procedure Next_Slot_Handler (Event : in out Timing_Event) is
         Current_Slot      : Any_Time_Slot;
         Current_Work_Slot : Any_Work_Slot;
         Current_WCB       : Work_Control_Block_Access;
         Current_Thread_Id : Thread_Id;
         Scheduling_Point  : Scheduling_Point_Type;
         Now               : Time;
      begin
         TTS_Debug ("Executing Next_Slot_Handler ... ");

         --  This is the current time, according to the plan
         Now := Next_Slot_Release;

         ---------------------------
         -- PROCESS STARTING SLOT --
         ---------------------------

         --  Update current slot index
         Current_Slot_Index := Next_Slot_Index;
         if Current_Slot_Index = Current_Plan.all'First then
            if Plan_Start_Pending then
               Now := Event.Time_Of_Event + Time_Offset;
               First_Plan_Release := Now;
               Plan_Start_Pending := False;
            end if;

            Plan_Start := Now;
            First_Slot_Release := Now;
            TTS_Debug ("Plan starts");
         end if;

         --  Obtain next slot index. The plan is repeated circularly
         if Next_Slot_Index < Current_Plan.all'Last then
            Next_Slot_Index := Next_Slot_Index + 1;
         else
            Next_Slot_Index := Current_Plan.all'First;
         end if;

         --  Obtain current slot
         Current_Slot := Current_Plan (Current_Slot_Index);

         --  Compute next slot start time
         Next_Slot_Release := Now + Current_Slot.Slot_Duration;
         --  Default values for end of work and hold releases.
         --  They will be overwritten if needed
         End_Of_Work_Release := Next_Slot_Release;
         Hold_Release := Next_Slot_Release;

         --  Default scheduling point
         Scheduling_Point := Next_Slot_Point;

         if Current_Slot.all in Empty_Slot'Class then
            -----------------------------
            --  Process an Empty_Slot  --
            -----------------------------

            TTS_Put_Line
              ("<EE:"
               & (Duration'Image
                    (To_Duration (Current_Slot.Slot_Duration) * 1000)
                  & " ms ")
               & ">  Slot: "
               & Current_Slot_Index'Image);

         elsif Current_Slot.all in Mode_Change_Slot'Class then
            ----------------------------------
            --  Process a Mode_Change_Slot  --
            ----------------------------------

            TTS_Put_Line
              ("<MM:"
               & (Duration'Image
                    (To_Duration (Current_Slot.Slot_Duration) * 1000)
                  & " ms ")
               & ">  Slot: "
               & Current_Slot_Index'Image);

            if Next_Plan /= null then
               --  There's a pending plan change.
               if Next_Mode_Release = End_Of_MC_Slot then
                  --  It takes effect at the end of the MC slot
                  Change_Plan (Next_Slot_Release);
               elsif Next_Mode_Release <= Now then
                  --  It takes effect right now
                  Change_Plan (Now);
               elsif Next_Mode_Release <= Next_Slot_Release then
                  --  It takes effect as scheduled, but before the end of
                  --   this slot
                  Change_Plan (Next_Mode_Release);
               else
                  --  Mode change request remains pending
                  null;
               end if;
            end if;

         elsif Current_Slot.all in Work_Slot'Class then
            -----------------------------
            --  Process a Work_Slot --
            -----------------------------

            Current_Work_Slot := Any_Work_Slot (Current_Slot);
            Current_WCB := WCB (Current_Work_Slot.Work_Id)'access;
            Current_Thread_Id := Current_WCB.Work_Thread_Id;

            if Current_Work_Slot.all in Initial_Slot'Class then
               declare
                  Current_Initial_Slot : Any_Initial_Slot :=
                    Any_Initial_Slot (Current_Work_Slot);
               begin
                  if Current_WCB.Skip_Count > 0 then
                     --  If the initial slot skipped, the whole sequence is skipped
                     Current_WCB.Skip_Count := Current_WCB.Skip_Count - 1;
                     Current_WCB.Is_Active := False;
                  else
                     -- System criticality level when the sequence of slots started
                     Current_WCB.Active_Criticality_Level :=
                       Current_Criticality_Level;

                     Current_WCB.Is_Active :=
                       (Current_Initial_Slot.Criticality_Level
                        >= Current_Criticality_Level
                        and
                          Current_Work_Slot.Work_Duration
                            (Current_WCB.Active_Criticality_Level)
                          > Time_Span_Zero);
                  end if;
               end;
            end if;

            TTS_Put_Line
              ("<"
               & (if Current_Work_Slot.Work_Type = Sync then "S" else "W")
               & Current_Work_Slot.Work_Id'Image
               & ": "
               & (Duration'Image
                    (To_Duration (Current_Slot.Slot_Duration) * 1000)
                  & " ms ")
               & "> "
               & " Slot: "
               & Current_Slot_Index'Image
               & " Active: "
               & Current_WCB.Is_Active'Image
               & " Waiting: "
               & Current_WCB.Is_Waiting'Image);

            if Current_WCB.Is_Active then
               case Current_Work_Slot.Work_Type is
                  when Sync                   =>
                     if Current_WCB.Skip_Count > 0 then
                        --  If the skip slot has been skipped
                        Current_WCB.Skip_Count := Current_WCB.Skip_Count - 1;
                     else
                        if not Current_WCB.Is_Sync then
                           raise Program_Error
                             with "Unexpected TT-task at Sync slot";
                        end if;

                        if Current_WCB.Is_Waiting then
                           Current_WCB.Last_Release := Now;
                           Current_WCB.Last_Slot_Release := Now;
                           Current_WCB.Is_Waiting := False;
                           Current_WCB.Has_Completed := True;
                           Set_True
                             (Release_Point (Current_Work_Slot.Work_Id));
                        elsif Current_Work_Slot.Is_Optional then
                           --  If the slot is optional, it is not an error if the ET
                           --    task has not invoked Wait_For_Sync
                           null;
                        else
                           --  Task is not waiting for its next activation.
                           --  It must have abandoned the TT Level or it is waiting in
                           --   a different work slot
                           raise Program_Error
                             with
                               ("Task is late to next activation for Work_Id "
                                & Current_Work_Slot.Work_Id'Image);
                        end if;
                     end if;

                  when Regular | Continuation =>

                     -- This value can be used within the Hold_Handler
                     End_Of_Work_Release :=
                       Now
                       + Current_Work_Slot.Work_Duration
                           (Current_WCB.Active_Criticality_Level);

                     --  Check what needs be done to the TT task of the new slot
                     if Current_WCB.Skip_Count > 0 then
                        Current_WCB.Skip_Count := Current_WCB.Skip_Count - 1;
                        -- If it is a Continuation slot,
                        --  this will ignore the whole continuation sequence
                        Current_WCB.Has_Completed := True;
                     else
                        if Current_WCB.Is_Sync then
                           raise Program_Error
                             with "Unexpected ET-task at Work slot";
                        end if;

                        if End_Of_Work_Release = Now then
                           --  Current work slot has reported a null work duration,
                           --   so the slot has to be skipped

                           --  Check if it is the final slot of a sliced sequence
                           --  and the work is not completed
                           if Current_WCB.Is_Sliced
                             and then Current_Work_Slot.Work_Type = Regular
                             and then not Current_WCB.Has_Completed
                           then
                              --  Handlers are set within the Overrun_Detected procedure
                              Scheduling_Point := None;
                              Overrun_Detected
                                (Current_Work_Slot, Event.Time_Of_Event);
                           end if;

                        elsif End_Of_Work_Release > Next_Slot_Release then

                           raise Program_Error
                             with
                               ("Work duration is beyond slot duration for Work_Id "
                                & Current_Work_Slot.Work_Id'Image
                                & " Slot Index "
                                & Current_Slot_Index'Image);

                        elsif Current_WCB.Has_Completed then

                           --  The TT task has abandoned the TT level or has called
                           --    Wait_For_Activation

                           if Current_WCB.Is_Sliced then
                              --  The completed TT task was running sliced and it has
                              --   completed, so this slot is not needed by the task.

                              null;

                           elsif Current_WCB.Is_Waiting then
                              --  TT task is waiting in Wait_For_Activation

                              --  Update WCB and release TT task
                              Current_WCB.Last_Release := Now;
                              Current_WCB.Last_Slot_Release := Now;
                              Current_WCB.Has_Completed := False;
                              Current_WCB.Is_Waiting := False;
                              Set_True
                                (Release_Point (Current_Work_Slot.Work_Id));

                              Scheduling_Point := End_Of_Work_Point;

                           elsif Current_Work_Slot.Is_Optional then
                              --  If the slot is optional, it is not an error if the TT
                              --    task has not invoked Wait_For_Activation

                              null;
                           else
                              --  Task is not waiting for its next activation.
                              --  It must have abandoned the TT Level or it is waiting in
                              --   a different work slot
                              raise Program_Error
                                with
                                  ("Task is late to next activation for Work_Id "
                                   & Current_Work_Slot.Work_Id'Image);
                           end if;

                        else
                           --  The TT task has not completed and no overrun has been
                           --    detected so far, so it must be running sliced and is
                           --    currently held from a previous exhausted slot, so it
                           --    must be resumed
                           pragma Assert (Current_WCB.Is_Sliced);

                           Current_WCB.Last_Slot_Release := Now;

                           --  Change thread state to runnable and insert it at the tail
                           --    of its active priority, which here implies that the
                           --    thread will be the next to execute
                           Continue (Current_Thread_Id);

                           Scheduling_Point := End_Of_Work_Point;
                        end if;
                     end if;

                     if Scheduling_Point = End_Of_Work_Point
                       and then Current_Work_Slot.Work_Type = Continuation
                       and then
                         Current_Work_Slot.Padding_Duration
                           (Current_WCB.Active_Criticality_Level)
                         > Time_Span_Zero
                     then
                        Scheduling_Point := Hold_Point;
                        Hold_Release :=
                          End_Of_Work_Release
                          - Current_Work_Slot.Padding_Duration
                              (Current_WCB.Active_Criticality_Level);

                        if Hold_Release < Now then
                           raise Program_Error
                             with
                               "Invalid padding duration in Slot "
                               & Current_Slot_Index'Image;
                        end if;
                     end if;

               end case;

               ---------------------------------------------
               --  Common actions to process the new slot --
               ---------------------------------------------

               --  The work inherits its Is_Sliced condition from the
               --   Is_Continuation property of the new slot
               --  This ensures that if the Work ID is not active or the slot has been ignored
               --   at the beginning of an sliced sequence, the sequence is ignored completely
               WCB (Current_Work_Slot.Work_Id).Is_Sliced :=
                 (Current_Work_Slot.Work_Type = Continuation);
            end if;

         end if;

         --  Set timing event for the next scheduling point
         case Scheduling_Point is
            when Next_Slot_Point   =>
               TTS_Debug
                 ("Set_Handler Next_Slot @ Next_Slot_Handler : "
                  & TT_Time (Next_Slot_Release));
               Next_Slot_Event.Set_Handler
                 (Next_Slot_Release - Overhead, Next_Slot_Handler_Access);

            when End_Of_Work_Point =>
               TTS_Debug
                 ("Set_Handler End_of_Work @ Next_Slot_Handler : "
                  & TT_Time (End_Of_Work_Release));
               End_Of_Work_Event.Set_Handler
                 (End_Of_Work_Release - Overhead, End_Of_Work_Handler_Access);
            --  Next_Slot handler will be set when this work finishes

            when Hold_Point        =>
               TTS_Debug
                 ("Set_Handler Hold @ Next_Slot_Handler : "
                  & TT_Time (Hold_Release));
               Hold_Event.Set_Handler
                 (Hold_Release - Overhead, Hold_Handler_Access);
            --  End_of_Work handler will be set when this event triggers

            when None              =>
               --  Used when an Overrun has been detected since the corresponding
               --  procedure already sets the proper handlers
               null;
         end case;
      exception
         when E : Constraint_Error =>
            Put_Line (Exception_Information (E));
            Put_Line (Exception_Message (E));
      end Next_Slot_Handler;

   end Time_Triggered_Scheduler;

end XAda.Dispatching.TTS;
