with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO;   use Ada.Text_IO;
with System;        use System;

with Epoch_Support; use Epoch_Support;
with Time_Stats;    use Time_Stats;

with XAda.Dispatching.TTS;
with TT_Utilities;
with TT_Patterns;
with TT_Mixed_Criticality;
with TTS_Plan_C;

package body TTS_Example_C is

   package TT_Plan is new TTS_Plan_C (Priority'Last - 1);
   use TT_Plan;

   package TT_Patt is new TT_Patterns (TTS);
   use TT_Patt;

   --  Auxiliary for printing absolute times with respect to plan/cycle --
   function Time_Str (T : Time) return String
   is (Duration'Image (To_Duration (T - TTS.Get_First_Plan_Release) * 1000)
       & " ms "
       & "|"
       & Duration'Image (To_Duration (T - TTS.Get_Last_Plan_Release) * 1000)
       & " ms ");

   -- TT tasks --

   --  Ending slot types are empty and a continuation slot that requires holding.
   --  Starting slots are initial, regular, initial sync, sync,
   --  initial continuation with padding and continuation with padding.
   --  The remaining slots behave like these when used as a starting or ending slot.
   --
   --  Stats data for all cases measured by task with this state.
   --  Positions 0 to 11 of the array contain the stats data for the
   --  following cases, respectively:
   --   0 => Em_In;  1 => Ho_In;
   --   2 => Em_Re;  3 => Ho_Re;
   --   4 => Em_IS;  5 => Ho_IS;
   --   6 => Em_Sy;  7 => Ho_Sy;
   --   8 => Em_IC;  9 => Ho_IC
   --  10 => Em_Co; 11 => Ho_Co;
   --
   --  Legend: Em = Empty;         Ho = Cont. with hold;
   --          In = Initial        Re = Regular;
   --          IS = Initial Sync   Sy = Sync;
   --          IC = Initial Continuation with Padding
   --          Co = Continuation with Padding
   --
   subtype Range_12 is Natural range 0 .. 11;
   Release_Data   : Stats_Data_Array (Range_12);
   Release_Labels : Stats_Labels_Array (Range_12) :=
     ("Em-In",
      "Ho-In",
      "Em-Re",
      "Ho-Re",
      "Em-IS",
      "Ho-IS",
      "Em-Sy",
      "Ho-Sy",
      "Em-IC",
      "Ho-IC",
      "Em-Co",
      "Ho-Co");

   --  State type for the task measuring release delay of initial and regular slots
   --   0 => Em_In;  1 => Ho_In;
   --   2 => Em_Re;  3 => Ho_Re;
   type In_Re_Task_State is new Initial_Final_Task_State with record
      Round : Natural := 0;
   end record;
   procedure Initialize (S : in out In_Re_Task_State) is null;
   procedure Initial_Code (S : in out In_Re_Task_State);
   procedure Final_Code (S : in out In_Re_Task_State);
   type Any_In_Re_Task_State is access all In_Re_Task_State;

   W1_State : aliased In_Re_Task_State;
   W1       :
     Initial_Final_TT_Task
       (Work_Id => 1, Task_State => W1_State'Access, Synced_Init => False);

   procedure Initial_Code (S : in out In_Re_Task_State) is
      Now           : Time := Clock;
      Release_Delay : Duration := To_Duration (Now - S.Release_Time);
      Offset        : Natural := S.Round mod 2;
      Index         : Range_12 := 0 + Offset;
   begin
      Put_Line ("W1: Initial slot released at " & Time_Str (Now));
      --   0 => Em_In;  1 => Ho_In;
      Update_Stats_Data
        (Release_Labels (Index), Release_Data (Index), Release_Delay);
   end Initial_Code;

   procedure Final_Code (S : in out In_Re_Task_State) is
      Now           : Time := Clock;
      Release_Delay : Duration := To_Duration (Now - S.Release_Time);
      Offset        : Natural := S.Round mod 2;
      Index         : Range_12 := 2 + Offset;
   begin
      Put_Line ("W1: Final slot released at " & Time_Str (Now));

      --   2 => Em_Re;  3 => Ho_Re;
      Update_Stats_Data
        (Release_Labels (Index), Release_Data (Index), Release_Delay);
      S.Round := S.Round + 1;
   end Final_Code;

   --  State type for the task measuring release delay of initial sync and sync slots
   --   4 => Em_IS;  5 => Ho_IS;
   --   6 => Em_Sy;  7 => Ho_Sy;
   type IS_Sy_Task_State is new Initial_Final_Task_State with record
      Round : Natural := 0;
   end record;
   procedure Initialize (S : in out IS_Sy_Task_State) is null;
   procedure Initial_Code (S : in out IS_Sy_Task_State);
   procedure Final_Code (S : in out IS_Sy_Task_State);
   type Any_IS_Sy_Task_State is access all IS_Sy_Task_State;

   W2_State : aliased IS_Sy_Task_State;
   W2       :
     Initial_Final_Synced_ET_Task
       (Work_Id => 2,
        Task_State => W2_State'Access,
        Synced_Init => False,
        Prio => Priority'Last - 2);

   procedure Initial_Code (S : in out IS_Sy_Task_State) is
      Now           : Time := Clock;
      Release_Delay : Duration := To_Duration (Now - S.Release_Time);
      Offset        : Natural := S.Round mod 2;
      Index         : Range_12 := 4 + Offset;
   begin
      Put_Line ("W2: Initial slot released at " & Time_Str (Now));
      --   4 => Em_IS;  5 => Ho_IS;
      Update_Stats_Data
        (Release_Labels (Index), Release_Data (Index), Release_Delay);
   end Initial_Code;

   procedure Final_Code (S : in out IS_Sy_Task_State) is
      Now           : Time := Clock;
      Release_Delay : Duration := To_Duration (Now - S.Release_Time);
      Offset        : Natural := S.Round mod 2;
      Index         : Range_12 := 6 + Offset;
   begin
      Put_Line ("W2: Final slot released at " & Time_Str (Now));
      --   6 => Em_Sy;  7 => Ho_Sy;
      Update_Stats_Data
        (Release_Labels (Index), Release_Data (Index), Release_Delay);
      S.Round := S.Round + 1;
   end Final_Code;

   --  State type for the task measuring release delay of initial continuation slots with padding
   --   8 => Em_IC;  9 => Ho_IC
   type IC_Task_State is new Simple_Task_State with record
      Round : Natural := 0;
   end record;
   procedure Initialize (S : in out IC_Task_State) is null;
   procedure Main_Code (S : in out IC_Task_State);
   type Any_IC_Task_State is access all IC_Task_State;

   W3_State : aliased IC_Task_State;
   W3       :
     Simple_TT_Task
       (Work_Id => 3, Task_State => W3_State'Access, Synced_Init => False);

   procedure Main_Code (S : in out IC_Task_State) is
      Now           : Time := Clock;
      Release_Delay : Duration := To_Duration (Now - S.Release_Time);
      Offset        : Natural := S.Round mod 2;
      Index         : Range_12 := 8 + Offset;
   begin
      Put_Line ("W3: Main slot released at " & Time_Str (Now));
      --   8 => Em_IC;  9 => Ho_IC
      Update_Stats_Data
        (Release_Labels (Index), Release_Data (Index), Release_Delay);
      S.Round := S.Round + 1;
   end Main_Code;

   --  State type for the task measuring release delay of continuation slots with padding
   --  10 => Em_Co; 11 => Ho_Co;
   type In_Co_Task_State is new Initial_Final_Task_State with record
      Round : Natural := 0;
   end record;
   procedure Initialize (S : in out In_Co_Task_State) is null;
   procedure Initial_Code (S : in out In_Co_Task_State);
   procedure Final_Code (S : in out In_Co_Task_State);
   type Any_In_Co_Task_State is access all In_Co_Task_State;

   W4_State : aliased In_Co_Task_State;
   W4       :
     Initial_Final_TT_Task
       (Work_Id => 4, Task_State => W4_State'Access, Synced_Init => False);

   procedure Initial_Code (S : in out In_Co_Task_State) is
   begin
      Put_Line ("W4: Initial slot released at " & Time_Str (Clock));
   end Initial_Code;

   procedure Final_Code (S : in out In_Co_Task_State) is
      Now           : Time := Clock;
      Release_Delay : Duration := To_Duration (Now - S.Release_Time);
      Offset        : Natural := S.Round mod 2;
      Index         : Range_12 := 10 + Offset;
   begin
      Put_Line ("W4: Final slot released at " & Time_Str (Now));

      --  10 => Em_Co; 11 => Ho_Co;
      Update_Stats_Data
        (Release_Labels (Index), Release_Data (Index), Release_Delay);
      S.Round := S.Round + 1;
   end Final_Code;

   --  Worker 5 is an auxiliary sliced task to cause "held" ending slots
   type Aux_Sliced_Task_State is new Simple_Task_State with null record;
   procedure Initialize (S : in out Aux_Sliced_Task_State) is null;
   procedure Main_Code (S : in out Aux_Sliced_Task_State);

   W5_State : aliased Aux_Sliced_Task_State;

   W5 :
     Simple_TT_Task
       (Work_Id => 5, Task_State => W5_State'Access, Synced_Init => False);

   --  To make sliced task busy wait for a given time
   procedure Main_Code (S : in out Aux_Sliced_Task_State) is
      --  CPU time taken by main code of task = 1.5 slots for 10 ms slots
      CPU_Interval  : constant Time_Span := Milliseconds (15);
      Tick_Size     : constant Time_Span := Milliseconds (5);
      Tick_Interval : Time_Span := Tick_Size;
      Current_Tick  : Time_Span := Clock - S.Release_Time;
   begin
      Put_Line
        ("W5: Main slot released at "
         & Time_Str (Clock)
         & " -- busy waiting for "
         & Duration'Image (To_Duration (CPU_Interval) * 1000)
         & " ms");
      loop
         Current_Tick := Clock - S.Release_Time;
         if Current_Tick >= Tick_Interval then
            Put_Line
              ("W5: Busy waiting... current tick = "
               & Duration'Image (To_Duration (Current_Tick) * 1000)
               & " ms");
            Tick_Interval := Tick_Interval + Tick_Size;
         end if;
         exit when Current_Tick >= CPU_Interval;
      end loop;
      Put_Line ("W5: Main code completed at " & Time_Str (Clock));
   end Main_Code;

   type Report_Task_State is new Simple_Task_State with record
      Round : Natural := 0;
   end record;
   procedure Initialize (S : in out Report_Task_State) is null;
   procedure Main_Code (S : in out Report_Task_State);

   W6_State : aliased Report_Task_State;

   --  Worker 6 takes the final slot in the plan to print stats results
   W6 :
     Simple_TT_Task
       (Work_Id => 6, Task_State => W6_State'Access, Synced_Init => False);

   procedure Main_Code (S : in out Report_Task_State) is
   begin
      S.Round := S.Round + 1;
      Put_Line
        ("W6: Printing stats results at round " & Natural'Image (S.Round));
      Show_Stats_Data (Release_Data, Release_Labels);
   end Main_Code;

   type Init_Plan_Task_State is new Simple_Task_State with null record;
   procedure Initialize (S : in out Init_Plan_Task_State) is null;
   procedure Main_Code (S : in out Init_Plan_Task_State);

   Init_Plan_State : aliased Init_Plan_Task_State;
   Init_Plan_Task  :
     Simple_TT_Task
       (Work_Id => 7,
        Task_State => Init_Plan_State'Access,
        Synced_Init => False);

   procedure Main_Code (S : in out Init_Plan_Task_State) is
      Now : Time := Clock;
   begin
      Put_Line ("Init_Plan_Task: Plan starts at " & Time_Str (Now));
      Put_Line
        ("Plan delay: "
         & To_Duration ((Now - S.Release_Time) * 1_000_000)'Image
         & " us");
   end Main_Code;

   -- task Background;
   -- task body Background is
   -- begin
   --    Put_Line ("Background: Starting at " & Time_Str (Clock));
   --    loop
   --       delay until Clock + Milliseconds (50);
   --       Put_Line ("Background: Tick at " & Time_Str (Clock));
   --    end loop;
   -- end Background;

   procedure Main is
      Start_Time : Time := Clock + Milliseconds (500);
   begin
      TTS.Set_Plan (TT_Plan.Plan_C'Access, Start_Time);
   end Main;

end TTS_Example_C;
