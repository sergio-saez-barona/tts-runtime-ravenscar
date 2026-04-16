with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO;   use Ada.Text_IO;
with System;        use System;

with Ada.Exceptions;          use Ada.Exceptions;
with Ada.Task_Identification; use Ada.Task_Identification;

with Epoch_Support; use Epoch_Support;
with Logging_Support;

with XAda.Dispatching.TTS;
with TT_Utilities;
with TT_Patterns;
with TT_Mixed_Criticality;

package body TTS_Example_A is

   Number_Of_Work_Ids : constant := 7;

   package TTS is new
     XAda.Dispatching.TTS
       (TT_Mixed_Criticality.No_Criticality_Levels,
        Number_Of_Work_Ids,
        Priority'Last - 1,
        False);

   package TT_Util is new TT_Utilities (TTS);
   use TT_Util;

   package TT_Patt is new TT_Patterns (TTS);
   use TT_Patt;

   --  Variables incremented by two TT sequences of IMs-F tasks
   Var_1, Var_2 : Natural := 0;
   pragma Volatile (Var_1);
   pragma Volatile (Var_2);

   --  Auxiliary for printing times --
   function Now (Current : Time) return String
   is (Duration'Image
         (To_Duration (Current - TTS.Get_First_Plan_Release) * 1000)
       & " ms "
       & "|"
       & Duration'Image
           (To_Duration (Current - TTS.Get_Last_Plan_Release) * 1000)
       & " ms ");

   -- TT tasks --

   type First_Simple_Task is new Simple_Task_State with null record;
   procedure Initialize (S : in out First_Simple_Task) is null;
   procedure Main_Code (S : in out First_Simple_Task);

   Wk1_Code : aliased First_Simple_Task;
   Wk1      :
     Simple_TT_Task
       (Work_Id => 1, Task_State => Wk1_Code'Access, Synced_Init => False);

   type First_IMF_Task is new Initial_Mandatory_Final_Task_State with record
      Counter : Natural := 0;
   end record;
   procedure Initialize (S : in out First_IMF_Task) is null;
   procedure Initial_Code (S : in out First_IMF_Task);
   procedure Mandatory_Code (S : in out First_IMF_Task);
   procedure Final_Code (S : in out First_IMF_Task);

   Wk2_State : aliased First_IMF_Task;
   Wk2       :
     InitialMandatorySliced_Final_TT_Task
       (Work_Id => 2, Task_State => Wk2_State'Access, Synced_Init => False);

   type Second_Simple_Task is new Simple_Task_State with null record;
   procedure Initialize (S : in out Second_Simple_Task) is null;
   procedure Main_Code (S : in out Second_Simple_Task);

   Wk3_Code : aliased Second_Simple_Task;
   Wk3      :
     Simple_TT_Task
       (Work_Id => 3, Task_State => Wk3_Code'Access, Synced_Init => False);

   type Second_IMF_Task is new Initial_Mandatory_Final_Task_State with record
      Counter : Natural := 0;
   end record;
   procedure Initialize (S : in out Second_IMF_Task) is null;
   procedure Initial_Code (S : in out Second_IMF_Task);
   procedure Mandatory_Code (S : in out Second_IMF_Task);
   procedure Final_Code (S : in out Second_IMF_Task);

   Wk4_Code : aliased Second_IMF_Task;
   Wk4      :
     InitialMandatorySliced_Final_TT_Task
       (Work_Id => 4, Task_State => Wk4_Code'Access, Synced_Init => False);

   type End_Of_Plan_IF_Task is new Initial_Final_Task_State with null record;
   procedure Initialize (S : in out End_Of_Plan_IF_Task) is null;
   procedure Initial_Code (S : in out End_Of_Plan_IF_Task);
   procedure Final_Code (S : in out End_Of_Plan_IF_Task);

   Wk5_Code : aliased End_Of_Plan_IF_Task;
   Wk5      :
     Initial_Final_TT_Task
       (Work_Id => 5, Task_State => Wk5_Code'Access, Synced_Init => False);

   type Synced_ET_Task is new Initial_OptionalFinal_Task_State with record
      Counter : Natural := 0;
   end record;
   procedure Initialize (S : in out Synced_ET_Task) is null;
   procedure Initial_Code (S : in out Synced_ET_Task);
   function Final_Is_Required (S : in out Synced_ET_Task) return Boolean;
   procedure Final_Code (S : in out Synced_ET_Task);

   ET6_Code : aliased Synced_ET_Task;
   ET6      :
     SyncedInitial_OptionalFinal_ET_Task
       (Work_Id => 6, Task_State => ET6_Code'Access, Synced_Init => False, Priority'Last -1);

   task type SyncedSporadic_ET_Task
     (Work_Id : TTS.TT_Work_Id;
      Offset  : Natural)
     with Priority => Priority'Last - 1;

   task body SyncedSporadic_ET_Task is
      Release_Time : Time;
   begin
      loop
         TTS.Wait_For_Sync (Work_Id, Release_Time);
         Put_Line
           ("Sporadic task waking up at "
            & Now (Release_Time + Milliseconds (Offset)));

         delay until Release_Time + Milliseconds (Offset);

         Put_Line ("Sporadic task interrupting at " & Now (Clock));
      end loop;
   exception
      when E : Storage_Error =>
         Put_Line
           ("Excepción en la tarea SyncedInitial_OptionalFinal_ET: "
            & Ada.Task_Identification.Image (Current_Task));
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end SyncedSporadic_ET_Task;

   Sp7 : SyncedSporadic_ET_Task (Work_Id => 7, Offset => 158);

   ms : constant Time_Span := Milliseconds (1);

   --  The TT plan
   TT_Plan : aliased TTS.Time_Triggered_Plan :=
     (TT_Slot (Empty, 100 * ms),  --  #00
      TT_Slot (Initial, 50 * ms, 1),  --  #00 Single slot for 1st seq. start
      TT_Slot (Empty, 150 * ms),  --  #01
      TT_Slot (Initial, 50 * ms, 3),  --  #02 Single slot for 2nd seq. start
      TT_Slot (Initial_Sync, 150 * ms, 7),  --  #03 Sp. 7, Sync point for sporadic task
      TT_Slot (Initial, 50 * ms, 2),  --  #04 IMF. 2, IMs part
      TT_Slot (Initial, 50 * ms, 4),  --  #05 IMF. 4, IMs part
      TT_Slot (Empty, 300 * ms),  --  #06
      TT_Slot (Continuation, 50 * ms, 2),  --  #07 IMF. 2, continuation of Ms part
      TT_Slot (Empty, 150 * ms),  --  #08
      TT_Slot (Terminal, 100 * ms, 4),  --  #09 IMF. 4, terminal of Ms part
      TT_Slot (Empty, 100 * ms),  --  #10
      TT_Slot (Terminal, 50 * ms, 2),  --  #11 IMF. 2, terminal of Ms part
      TT_Slot (Initial_Sync, 150 * ms, 6),  --  #12 ET. 6, Sync Point for ET Task
      TT_Slot (Final, 50 * ms, 4),  --  #13 IMF. 4, F part
      TT_Slot (Empty, 100 * ms),  --  #14
      TT_Slot (Final, 50 * ms, 2),  --  #15 IMF. 2, F part
      TT_Slot (Empty, 80 * ms),  --  #16
      TT_Slot (Initial, 50 * ms, 5),  --  #17 IF. 5, I part of end of plan
      TT_Slot (Empty, 70 * ms),  --  #18
      TT_Slot (Final, 70 * ms, 6),  --  #19 ET. 6, F part of synced ET
      TT_Slot (Final, 50 * ms, 5),  --  #20 IF. 5, F part of end of plan
      TT_Slot (Mode_Change, 80 * ms));  --  #21

   --  Actions of sequence initialisations
   procedure Main_Code (S : in out First_Simple_Task) is
      --  Simple_TT task with ID = 1
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      New_Line;
      Put_Line ("------------------------");
      Put_Line ("Starting plan!");
      Put_Line ("------------------------");
      New_Line;

      --  Log --
      Put_line
        ("Worker"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      Var_1 := 0;
      Put_Line ("First_Init_Task.Main_Code ended at " & Now (Clock));
   end Main_Code;

   procedure Main_Code (S : in out Second_Simple_Task) is
      --  Simple_TT task with ID = 3
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      --  Log --
      Put_line
        ("Worker"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      Var_2 := 0;
      Put_Line ("Second_Init_Task.Main_Code ended at " & Now (Clock));
   end Main_Code;

   --  Actions of first sequence: IMs-F task with ID = 2
   procedure Initial_Code (S : in out First_IMF_Task) is
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      --  Log --
      Put_line
        ("Worker"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      S.Counter := Var_1;
      Put_Line ("First_IMF_Task.Initial_Code ended at " & Now (Clock));
   end Initial_Code;

   procedure Mandatory_Code (S : in out First_IMF_Task) is
   begin
      Put_Line
        ("First_IMF_Task.Mandatory_Code sliced started at " & Now (Clock));

      while S.Counter < 250_000 loop
         S.Counter := S.Counter + 1;
         if S.Counter mod 20_000 = 0 then
            Put_Line
              ("First_IMF_Task.Mandatory_Code sliced step " & Now (Clock));
         end if;
      end loop;

      Put_Line
        ("First_IMF_Task.Mandatory_Code sliced ended at " & Now (Clock));
   end Mandatory_Code;

   procedure Final_Code (S : in out First_IMF_Task) is
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      --  Log --
      Put_line
        ("Worker"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      Var_1 := S.Counter;
      Put_Line
        ("First_IMF_Task.Final_Code Seq. 1 with Var_1 ="
         & Var_1'Image
         & " at"
         & Now (Clock));
   end Final_Code;

   --  Actions of Second sequence: IMs-F task with ID = 4
   procedure Initial_Code (S : in out Second_IMF_Task) is
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      --  Log --
      Put_line
        ("Worker"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      S.Counter := Var_2;
      Put_Line ("Second_IMF_Task.Initial_Code ended at " & Now (Clock));
   end Initial_Code;

   procedure Mandatory_Code (S : in out Second_IMF_Task) is
   begin
      Put_Line
        ("Second_IMF_Task.Mandatory_Code sliced started at " & Now (Clock));
      while S.Counter < 100_000 loop
         S.Counter := S.Counter + 1;
         if S.Counter mod 20_000 = 0 then
            Put_Line
              ("Second_IMF_Task.Mandatory_Code sliced step " & Now (Clock));
         end if;
      end loop;
      Put_Line
        ("Second_IMF_Task.Mandatory_Code sliced ended at " & Now (Clock));
   end Mandatory_Code;

   procedure Final_Code (S : in out Second_IMF_Task) is
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      --  Log --
      Put_line
        ("Worker"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      Var_2 := S.Counter;
      Put_Line
        ("Second_IMF_Task.Final_Code Seq. 2 with Var_2 ="
         & Var_2'Image
         & " at"
         & Now (Clock));
   end Final_Code;

   --  End of plan actions: I-F task with ID = 4
   procedure Initial_Code (S : in out End_Of_Plan_IF_Task) is
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      --  Log --
      Put_line
        ("Worker"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      Put_Line ("End_Of_Plan_IF_Task.Initial_Code at" & Now (Clock));
      Put_Line ("Value of Var_1 =" & Var_1'Image);
      Put_Line ("Value of Var_2 =" & Var_2'Image);
   end Initial_Code;

   procedure Final_Code (S : in out End_Of_Plan_IF_Task) is
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      --  Log --
      Put_line
        ("Worker"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      Put_Line ("End_Of_Plan_IF_Task.Final_Code at" & Now (Clock));
      New_Line;
      Put_Line ("------------------------");
      Put_Line ("Starting all over again!");
      Put_Line ("------------------------");
      New_Line;
   end Final_Code;

   procedure Initial_Code (S : in out Synced_ET_Task) is
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

   function Final_Is_Required (S : in out Synced_ET_Task) return Boolean is
      Condition : Boolean;
   begin
      Condition := (S.Counter mod 2 = 0);
      Put_Line
        ("Synced_ET_Task.Final_Is_Required with condition = "
         & Condition'Image
         & " at"
         & Now (Clock));
      return Condition;
   end Final_Is_Required;

   procedure Final_Code (S : in out Synced_ET_Task) is
      Jitter : Time_Span := Clock - S.Release_Time;
   begin
      --  Log --
      Put_line
        ("Worker"
         & Integer (S.Work_Id)'Image
         & " Jitter = "
         & Duration'Image (1000.0 * To_Duration (Jitter))
         & " ms.");
      --  Log --

      Put_Line
        ("Synced_ET_Task.Final_Code with counter = "
         & S.Counter'Image
         & " at"
         & Now (Clock));
   end Final_Code;

   ----------
   -- Main --
   ----------

   procedure Main is
   begin
      Put_Line ("Waiting for epoch");
      delay until Epoch_Support.Epoch;
      TTS.Set_Plan (TT_Plan'Access);
      Put_Line ("Waiting for Judgement day");
      delay until Ada.Real_Time.Time_Last;
   end Main;

end TTS_Example_A;
