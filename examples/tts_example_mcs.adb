with Ada.Real_Time; use Ada.Real_Time;
with Ada.Real_Time.Timing_Events;
with Logging_Support;
with Ada.Text_IO;   use Ada.Text_IO;
with System;        use System;

with Epoch_Support; use Epoch_Support;

with XAda.Dispatching.TTS;
with TT_Mixed_Criticality; use TT_Mixed_Criticality;
with TT_Patterns;
with TTS_Plan_MCS_Dual;

package body TTS_Example_MCS is

   package TT_Plan is new TTS_Plan_MCS_Dual (Priority'Last - 1);
   use TT_Plan;

   package TT_Patt is new TT_Patterns (TTS);
   use TT_Patt;

   function Now (Current : Time) return String
   is (Duration'Image
         (To_Duration (Current - TTS.Get_First_Plan_Release) * 1000)
       & " ms "
       & "|"
       & Duration'Image
           (To_Duration (Current - TTS.Get_Last_Plan_Release) * 1000)
       & " ms ");

   procedure TT_Put_Line (Item : in String) is
      Work_Slot : TTS.Any_Work_Slot :=
        TTS.Any_Work_Slot (TTS.Get_Current_Slot);
   begin
      Put_Line
        ("["
         & Work_Slot.Work_Id'Image
         & "] @ "
         & TTS.Get_System_Criticality_Level'Image
         & " - "
         & TTS.Get_Active_Criticality_Level (Work_Slot.Work_Id)'Image
         & " > "
         & Item);
   end TT_Put_Line;

   procedure Busy_Wait
     (Owner : String; Wait_Duration : Time_Span; Tick : Time_Span)
   is
      Start            : Time := Clock;
      Current_Duration : Time_Span := Clock - Start;
      Current_Tick     : Time_Span := Tick;
   begin
      while Current_Duration < Wait_Duration loop
         if Current_Duration >= Current_Tick then
            Put_Line
              (Owner
               & ": Busy waiting... current tick = "
               & Duration'Image (To_Duration (Current_Duration) * 1000)
               & " ms");
            Current_Tick := Current_Tick + Tick;
         end if;
         Current_Duration := Clock - Start;
      end loop;
   end Busy_Wait;

   -- TT tasks --

   type Seq1_IMF_Task is new Initial_Mandatory_Final_Task_State with record
      Counter : Natural := 0;
      Iter    : Natural := 0;
   end record;
   procedure Initialize (S : in out Seq1_IMF_Task) is null;
   procedure Initial_Code (S : in out Seq1_IMF_Task);
   procedure Mandatory_Code (S : in out Seq1_IMF_Task);
   procedure Final_Code (S : in out Seq1_IMF_Task);

   Seq1_State : aliased Seq1_IMF_Task;
   Seq1       :
     InitialMandatorySliced_Final_TT_Task
       (Work_Id => 1, Task_State => Seq1_State'Access);

   type Seq2_IMF_Task is new Initial_Mandatory_Final_Task_State with record
      Counter : Natural := 0;
   end record;
   procedure Initialize (S : in out Seq2_IMF_Task) is null;
   procedure Initial_Code (S : in out Seq2_IMF_Task);
   procedure Mandatory_Code (S : in out Seq2_IMF_Task);
   procedure Final_Code (S : in out Seq2_IMF_Task);

   Seq2_State : aliased Seq2_IMF_Task;
   Seq2       :
     InitialMandatorySliced_Final_TT_Task
       (Work_Id => 2, Task_State => Seq2_State'Access);

   type Wk3_Simple_Task is new Simple_Task_State with record
      Iter : Natural := 0;
   end record;
   procedure Initialize (S : in out Wk3_Simple_Task) is null;
   procedure Main_Code (S : in out Wk3_Simple_Task);

   Wk3_Code : aliased Wk3_Simple_Task;
   Wk3      : Simple_TT_Task (Work_Id => 3, Task_State => Wk3_Code'Access);

   type Wk4_Simple_Task is new Simple_Task_State with null record;
   procedure Initialize (S : in out Wk4_Simple_Task) is null;
   procedure Main_Code (S : in out Wk4_Simple_Task);

   Wk4_Code : aliased Wk4_Simple_Task;
   Wk4      : Simple_TT_Task (Work_Id => 4, Task_State => Wk4_Code'Access);

   type Seq5_Synced_ET_Task is new Initial_OptionalFinal_Task_State with record
      Counter : Natural := 0;
   end record;
   procedure Initialize (S : in out Seq5_Synced_ET_Task) is null;
   procedure Initial_Code (S : in out Seq5_Synced_ET_Task);
   function Final_Is_Required (S : in out Seq5_Synced_ET_Task) return Boolean;
   procedure Final_Code (S : in out Seq5_Synced_ET_Task);

   Seq5_Code : aliased Seq5_Synced_ET_Task;
   Seq5      :
     SyncedInitial_OptionalFinal_ET_Task
       (Work_Id => 5,
        Task_State => Seq5_Code'Access,
        Prio => Priority'Last - 2);

   --  Actions of Sequence 1: IMs-F task with ID = 1
   procedure Initial_Code (S : in out Seq1_IMF_Task) is
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      New_Line;
      Put_Line ("------------------------");
      Put_Line
        ("Starting plan @ CL " & TTS.Get_System_Criticality_Level'Image);
      Put_Line ("------------------------");
      New_Line;

      --  Log --
      TT_Put_line
        ("Worker"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      S.Counter := 0;
      S.Iter := S.Iter + 1;

      TT_Put_Line ("Seq1_IMF_Task.Initial_Code ended at " & Now (Clock));
   end Initial_Code;

   procedure Mandatory_Code (S : in out Seq1_IMF_Task) is
   begin
      TT_Put_Line
        ("First_IMF_Task.Mandatory_Code sliced started at " & Now (Clock));

      while S.Counter < 200_000 + (100_000 * (S.Iter mod 2)) loop
         S.Counter := S.Counter + 1;
         if S.Counter mod 20_000 = 0 then
            TT_Put_Line
              ("First_IMF_Task.Mandatory_Code sliced step " & Now (Clock));
         end if;
      end loop;

      TT_Put_Line
        ("Seq1_IMF_Task.Mandatory_Code sliced ended at " & Now (Clock));
   end Mandatory_Code;

   procedure Final_Code (S : in out Seq1_IMF_Task) is
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      --  Log --
      TT_Put_line
        ("Worker"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      TT_Put_Line
        ("Seq1_IMF_Task.Final_Code Seq. 1 with Counter ="
         & S.Counter'Image
         & " at"
         & Now (Clock));
   end Final_Code;

   --  Actions of Sequence 2: IMs-F task with ID = 2
   procedure Initial_Code (S : in out Seq2_IMF_Task) is
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      --  Log --
      TT_Put_line
        ("Worker"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      S.Counter := 0;
      TT_Put_Line ("Seq2_IMF_Task.Initial_Code ended at " & Now (Clock));
   end Initial_Code;

   procedure Mandatory_Code (S : in out Seq2_IMF_Task) is
   begin
      TT_Put_Line
        ("Seq2_IMF_Task.Mandatory_Code sliced started at " & Now (Clock));
      while S.Counter < 200_000 loop
         S.Counter := S.Counter + 1;
         if S.Counter mod 20_000 = 0 then
            TT_Put_Line
              ("Seq2_IMF_Task.Mandatory_Code sliced step " & Now (Clock));
         end if;
      end loop;
      TT_Put_Line
        ("Seq2_IMF_Task.Mandatory_Code sliced ended at " & Now (Clock));
   end Mandatory_Code;

   procedure Final_Code (S : in out Seq2_IMF_Task) is
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      --  Log --
      TT_Put_line
        ("Worker"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      TT_Put_Line
        ("Seq2_IMF_Task.Final_Code Seq. 2 with Counter ="
         & S.Counter'Image
         & " at"
         & Now (Clock));
   end Final_Code;

   --  Actions of Worker 3: Simple task with ID = 3
   procedure Main_Code (S : in out Wk3_Simple_Task) is
      --  Simple_TT task with ID = 1
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      --  Log --
      TT_Put_line
        ("Worker"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      TT_Put_Line ("Wk3_Simple_Task.Main_Code ended at " & Now (Clock));

      S.Iter := S.Iter + 1;
      if S.Iter mod 4 = 0 then
         TTS.Set_System_Criticality_Level (LO);
      end if;

   end Main_Code;

   -- Actions of Worker 4: Simple task with ID = 4
   procedure Main_Code (S : in out Wk4_Simple_Task) is
      --  Simple_TT task with ID = 3
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      --  Log --
      TT_Put_line
        ("Worker"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      TT_Put_Line ("Wk4_Simple_Task.Main_Code ended at " & Now (Clock));
   end Main_Code;

   --  Actions of Sequence 5: Synced-ET task with ID = 5
   procedure Initial_Code (S : in out Seq5_Synced_ET_Task) is
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      --  Log --
      Put_line
        ("Synced"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      S.Counter := S.Counter + 1;
      Put_Line
        ("Synced_ET_Task.Synced_Code with counter = "
         & S.Counter'Image
         & " at"
         & Now (Clock));
   end Initial_Code;

   function Final_Is_Required (S : in out Seq5_Synced_ET_Task) return Boolean
   is
      Condition : Boolean;
   begin
      Condition := (S.Counter mod 2 = 1);
      Put_Line
        ("Synced_ET_Task.Final_Is_Required with condition = "
         & Condition'Image
         & " at"
         & Now (Clock));
      return Condition;
   end Final_Is_Required;

   procedure Final_Code (S : in out Seq5_Synced_ET_Task) is
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      --  Log --
      TT_Put_line
        ("Worker"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      TT_Put_Line
        ("Seq5_Synced_ET_Task.Final_Code with counter = "
         & S.Counter'Image
         & " at"
         & Now (Clock));
   end Final_Code;

   --------------------------
   --  Criticality Manager --
   --------------------------

   protected Criticality_Manager
     with Priority => System.Interrupt_Priority'Last
   is
      procedure Overrun_Handler
        (Event : in out Ada.Real_Time.Timing_Events.Timing_Event);

   end Criticality_Manager;

   protected body Criticality_Manager is

      procedure Overrun_Handler
        (Event : in out Ada.Real_Time.Timing_Events.Timing_Event) is
      begin
         Put_Line ("Overrun detected!!");
         TTS.Set_System_Criticality_Level (HI);
      end Overrun_Handler;

   end Criticality_Manager;

   ----------
   -- Main --
   ----------

   procedure Main is
   begin
      TTS.Set_System_Criticality_Level (LO);
      TTS.Set_Default_Overrun_Handler
        (Criticality_Manager.Overrun_Handler'Access);
      delay until Epoch_Support.Epoch;
      TTS.Set_Plan (Plan_MCS_Dual'Access);
      delay until Ada.Real_Time.Time_Last;
   end Main;

end TTS_Example_MCS;
