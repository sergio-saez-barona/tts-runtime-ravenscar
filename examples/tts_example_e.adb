with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO;   use Ada.Text_IO;
with System;        use System;

with Epoch_Support; use Epoch_Support;

with XAda.Dispatching.TTS;
with TT_Utilities;
with TT_Patterns;
with TT_Mixed_Criticality;
with TTS_Plan_E;

package body TTS_Example_E is

   Number_Of_Work_Ids : constant := 6;

   package TT_Plan is new TTS_Plan_E (Number_Of_Work_Ids, Priority'Last - 1);
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

   type Stats_Data is record
      N   : Natural := 0;              --  Sample size so far    
      Max : Duration := 0.0;            --  Maximum measured value
      Min : Duration := Duration'Last;  --  Minimum measured value
      Avg : Duration := 0.0;            --  Average
   end record;

   procedure Update_Stats_Data
     (D : in out Stats_Data; Release_Delay : Duration) is
   begin
      --  One more sample
      D.N := D.N + 1;
      --  Calculate average
      D.Avg := (D.Avg * (D.N - 1) + Release_Delay) / D.N;
      --  Update Max
      if Release_Delay > D.Max then
         D.Max := Release_Delay;
      end if;
      --  Update Min
      if Release_Delay < D.Min then
         D.Min := Release_Delay;
      end if;
   end Update_Stats_Data;

   subtype Range_12 is Natural range 0..11;
   
   type Release_Cases is array (Range_12) of Stats_Data;

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
   Release_Data : Release_Cases;

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

   procedure Initial_Code (S : in out In_Re_Task_State) is
      Release_Delay : Duration := To_Duration (Clock - S.Release_Time);
      Offset        : Natural := S.Round mod 2;
   begin
      --   0 => Em_In;  1 => Ho_In;
      Update_Stats_Data (Release_Data (0 + Offset), Release_Delay);
      S.Round := S.Round + 1;
   end Initial_Code;

   procedure Final_Code (S : in out In_Re_Task_State) is
      Release_Delay : Duration := To_Duration (Clock - S.Release_Time);
      Offset        : Natural := S.Round mod 2;
   begin
      --   2 => Em_Re;  3 => Ho_Re;
      Update_Stats_Data (Release_Data (2 + Offset), Release_Delay);
      S.Round := S.Round + 1;
   end Final_Code;

   W1_State : aliased In_Re_Task_State;
   W1       :
     Initial_Final_TT_Task
       (Work_Id => 1, Task_State => W1_State'Access, Synced_Init => False);

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

   procedure Initial_Code (S : in out IS_Sy_Task_State) is
      Release_Delay : Duration := To_Duration (Clock - S.Release_Time);
      Offset        : Natural := S.Round mod 2;
   begin
      --   4 => Em_IS;  5 => Ho_IS;
      Update_Stats_Data (Release_Data (4 + Offset), Release_Delay);
      S.Round := S.Round + 1;
   end Initial_Code;

   procedure Final_Code (S : in out IS_Sy_Task_State) is
      Release_Delay : Duration := To_Duration (Clock - S.Release_Time);
      Offset        : Natural := S.Round mod 2;
   begin
      --   6 => Em_Sy;  7 => Ho_Sy;
      Update_Stats_Data (Release_Data (6 + Offset), Release_Delay);
      S.Round := S.Round + 1;
   end Final_Code;

   W2_State : aliased IS_Sy_Task_State;
   W2       :
     Initial_Final_Synced_ET_Task
       (Work_Id => 2, Task_State => W2_State'Access, Synced_Init => False);

   --  State type for the task measuring release delay of initial continuation slots with padding
   --   8 => Em_IC;  9 => Ho_IC
   type IC_Task_State is new Simple_Task_State with record
      Round : Natural := 0;
   end record;
   procedure Initialize (S : in out IC_Task_State) is null;
   procedure Main_Code (S : in out IC_Task_State);
   type Any_IC_Task_State is access all IC_Task_State;

   procedure Main_Code (S : in out IC_Task_State) is
      Release_Delay : Duration := To_Duration (Clock - S.Release_Time);
      Offset        : Natural := S.Round mod 2;
   begin
      --   8 => Em_IC;  9 => Ho_IC
      Update_Stats_Data (Release_Data (8 + Offset), Release_Delay);
      S.Round := S.Round + 1;
   end Main_Code;

   W3_State : aliased IC_Task_State;
   W3       :
     Simple_TT_Task
       (Work_Id => 3, Task_State => W3_State'Access, Synced_Init => False);

   --  State type for the task measuring release delay of continuation slots with padding
   --  10 => Em_Co; 11 => Ho_Co;
   type In_Co_Task_State is new Initial_Final_Task_State with record
      Round : Natural := 0;
   end record;
   procedure Initialize (S : in out In_Co_Task_State) is null;
   procedure Initial_Code (S : in out In_Co_Task_State) is null;
   procedure Final_Code (S : in out In_Co_Task_State);
   type Any_In_Co_Task_State is access all In_Co_Task_State;

   procedure Final_Code (S : in out In_Co_Task_State) is
      Release_Delay : Duration := To_Duration (Clock - S.Release_Time);
      Offset        : Natural := S.Round mod 2;
   begin
      --  10 => Em_Co; 11 => Ho_Co;
      Update_Stats_Data (Release_Data (10 + Offset), Release_Delay);
      S.Round := S.Round + 1;
   end Final_Code;

   W4_State : aliased IC_Task_State;
   W4       :
     Simple_TT_Task
       (Work_Id => 4, Task_State => W3_State'Access, Synced_Init => False);
   
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
      CPU_Interval : constant Time_Span := Milliseconds (15);
   begin
      loop
         exit when Clock - S.Release_Time >= CPU_Interval;
      end loop;
   end Main_Code;

   type Report_Task_State is new Simple_Task_State with null record;
   procedure Initialize (S : in out Report_Task_State) is null;
   procedure Main_Code (S : in out Report_Task_State);

   W6_State : aliased Report_Task_State;

   --  Worker 4 takes the final slot in the plan to print stats results
   W6 :
     Simple_TT_Task
       (Work_Id => 6, Task_State => W6_State'Access, Synced_Init => False);

   type RO_Text_Labels is array (Range_12) of String (1 .. 2);
   RO_Label : RO_Text_Labels :=
     ("ER", "EO", "MR", "MO", "RR", "RO", "SR", "SO", "OR", "OO", "HR", "HO");
   type Sy_Text_Labels is array (Mod_6) of String (1 .. 2);
   Sy_Label : Sy_Text_Labels := ("ES", "MS", "RS", "SS", "OS", "HS");

   --  Global max and min
   G_Max : Duration := 0.0;
   G_Min : Duration := Duration'Last;

   procedure Main_Code (S : in out Report_Task_State) is
      Max : Duration := 0.0;
      Min : Duration := Duration'Last;
   begin
      Put_Line (" -------- Times in milliseconds -------");
      Put_Line ("| Tr    Max         Avg         Min    |");
      Put_Line (" --------------------------------------");
      for I in Mod_12 loop
         Put
           (RO_Label (I)
            & ":"
            & Duration'Image (RO_Data (I).Max * 1_000.0)
            & Duration'Image (RO_Data (I).Avg * 1_000.0)
            & Duration'Image (RO_Data (I).Min * 1_000.0));
         New_Line;
         if RO_Data (I).Max > Max then
            Max := RO_Data (I).Max;
         end if;
         if RO_Data (I).Min < Min then
            Min := RO_Data (I).Min;
         end if;
      end loop;
      New_Line;
      for I in Mod_6 loop
         Put
           (Sy_Label (I)
            & ": "
            & Duration'Image (Sy_Data (I).Max * 1_000.0)
            & Duration'Image (Sy_Data (I).Avg * 1_000.0)
            & Duration'Image (Sy_Data (I).Min * 1_000.0));
         New_Line;
         if Sy_Data (I).Max > Max then
            Max := Sy_Data (I).Max;
         end if;
         if Sy_Data (I).Min < Min then
            Min := Sy_Data (I).Min;
         end if;
      end loop;
      New_Line;
      Put_Line
        (" Max ="
         & Duration'Image (Max * 1_000.0)
         & "     Min ="
         & Duration'Image (Min * 1_000.0));

      if G_Max < Max then
         G_Max := Max;
      end if;
      if G_Min > Min then
         G_Min := Min;
      end if;
      Put_Line
        ("GMax ="
         & Duration'Image (G_Max * 1_000.0)
         & "    GMin ="
         & Duration'Image (G_Min * 1_000.0));

      Put_Line (" --------------------------------------");
      New_Line;
      New_Line;
   end Main_Code;

   procedure Main is
   begin
      delay until Epoch_Support.Epoch;
      TTS.Set_Plan (TT_Plan.Plan_E'Access);
      delay until Ada.Real_Time.Time_Last;
   end Main;

end TTS_Example_E;
