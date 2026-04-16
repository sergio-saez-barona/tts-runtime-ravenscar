with Ada.Real_Time;                use Ada.Real_Time;
with Ada.Real_Time.Timing_Events;  use Ada.Real_Time.Timing_Events;
with Ada.Text_IO;                  use Ada.Text_IO;
with Ada.Synchronous_Task_Control; use Ada.Synchronous_Task_Control;
with Epoch_Support;
with System;                       use System;

with Time_Stats;     use Time_Stats;
with Ada.Exceptions; use Ada.Exceptions;

package body RT_Example_A is

   Alarm_Jitter : Time_Span := Microseconds (4);

   Wait_Point : Suspension_Object;

   protected Scheduler
     with Priority => Interrupt_Priority'Last
   is
      procedure Initialize (Init_Time : Time);
      entry Wait_For_Release (Wake_Up_Time : out Time);

      procedure Timed_Release (At_Time : Time);
      procedure Timed_Open (At_Time : Time);
      procedure Release;
      procedure Open;

      function Get_Start_Time return Time;
      function Get_Epoch return Time;
      function Get_Release_Time return Time;
   private
      Start_Time   : Time := Time_First;
      Epoch        : Time := Time_First;
      Released     : Boolean := False;
      Release_Time : Time := Time_First;

      procedure Init_Handler (Event : in out Timing_Event);
      Init_Handler_Access : Timing_Event_Handler := Init_Handler'Access;
      Init_Event          : Timing_Event;

      procedure Release_Handler (Event : in out Timing_Event);
      Release_Handler_Access : Timing_Event_Handler := Release_Handler'Access;
      Release_Event          : Timing_Event;

      procedure Timed_Open_Handler (Event : in out Timing_Event);
      Timed_Open_Handler_Access : Timing_Event_Handler :=
        Timed_Open_Handler'Access;
      Timed_Open_Event          : Timing_Event;
   end Scheduler;

   protected body Scheduler is
      procedure Initialize (Init_Time : Time) is
      begin
         Start_Time := Init_Time;
         Released := False;
         Init_Event.Set_Handler
           (Init_Time + Milliseconds (1), Init_Handler_Access);
      end Initialize;

      procedure Init_Handler (Event : in out Timing_Event) is
      begin
         Epoch := Event.Time_of_Event;
      end Init_Handler;

      procedure Release_Handler (Event : in out Timing_Event) is
      begin
         -- Release_Time has already been set to the intended release time by Timed_Release or Release,
         --  so we just need to set Released to True
         Released := True;
      end Release_Handler;

      procedure Timed_Open_Handler (Event : in out Timing_Event) is
      begin
         Set_True (Wait_Point);
      end Timed_Open_Handler;

      entry Wait_For_Release (Wake_Up_Time : out Time) when Released is
      begin
         Wake_Up_Time := Release_Time;
         Released := False;
      end Wait_For_Release;

      procedure Timed_Release (At_Time : Time) is
      begin
         Release_Time := At_Time;
         Release_Event.Set_Handler
           (At_Time - Alarm_Jitter, Release_Handler_Access);
      end Timed_Release;

      procedure Timed_Open (At_Time : Time) is
      begin
         Release_Time := At_Time;
         Timed_Open_Event.Set_Handler
           (At_Time - Alarm_Jitter, Timed_Open_Handler_Access);
      end Timed_Open;

      procedure Release is
      begin
         Release_Time := Clock;
         Released := True;
      end Release;

      procedure Open is
      begin
         Release_Time := Clock;
         Set_True (Wait_Point);
      end Open;

      function Get_Start_Time return Time
      is (Start_Time);

      function Get_Epoch return Time
      is (Epoch);

      function Get_Release_Time return Time
      is (Release_Time);
   end Scheduler;

   subtype Worker_Range is Natural range 0 .. 3;
   Release_Data   : Stats_Data_Array (Worker_Range);
   Release_Labels : Stats_Labels_Array (Worker_Range) :=
     ("InmPO", "InmSO", "TimPO", "TimSO");

   task Worker
     with Priority => Priority'Last;

   task body Worker is
      Release_Time  : Time;
      Wake_Up_Time  : Time;
      Counter       : Integer := 0;
      Release_Delay : Time_Span;
   begin
      loop
         -- Wait for scheduler release
         if Counter mod 2 = 0 then
            Scheduler.Wait_For_Release (Wake_Up_Time);
            Release_Time := Clock;
         else
            Suspend_Until_True (Wait_Point);
            Release_Time := Clock;
            Wake_Up_Time := Scheduler.Get_Release_Time;
         end if;
         Release_Delay := Release_Time - Wake_Up_Time;

         Put_Line
           (Counter'Image
            & " Worker release delay: "
            & To_Duration (Release_Delay * 1_000_000)'Image (1 .. 8)
            & " us");
         Update_Stats_Data
           (Release_Labels (Counter),
            Release_Data (Counter),
            To_Duration (Release_Delay));

         Counter := (Counter + 1) mod 4;

         if Counter = 0 then
            Show_Stats_Data (Release_Data, Release_Labels);
         end if;
      end loop;
   exception
      when E : others =>
         Put_Line ("Worker task received an exception");
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end Worker;

   Init_Time : Time;

   function Time_Str (T : Time) return String is
   begin
      return Duration'Image (To_Duration (T - Init_Time) * 1_000) & " ms";
   end Time_Str;

   procedure Main is
      Wake_Up_Time : Time;
   begin
      Scheduler.Initialize (Clock);
      --  Wait for scheduler to initialize and set epoch
      delay until Clock + Milliseconds (100);

      Init_Time := Scheduler.Get_Start_Time;
      Wake_Up_Time := Scheduler.Get_Epoch;

      Put_Line ("Scheduler epoch: " & Time_Str (Wake_Up_Time));

      loop
         -- Inmediate release using a Protected Object entry
         Wake_Up_Time := Wake_Up_Time + Milliseconds (100);
         delay until Wake_Up_Time;

         Put_Line ("Immediate PO release at " & Time_Str (Clock));
         Scheduler.Release;

         -- Inmediate release using a Suspension Object
         Wake_Up_Time := Wake_Up_Time + Milliseconds (100);
         delay until Wake_Up_Time;

         Put_Line ("Immediate SO release at " & Time_Str (Clock));
         Scheduler.Open;

         -- Timed release using a protected object entry
         Wake_Up_Time := Wake_Up_Time + Milliseconds (100);
         Put_Line ("Timed PO release at " & Time_Str (Wake_Up_Time));
         Scheduler.Timed_Release (Wake_Up_Time);
         delay until Wake_Up_Time;

         -- Timed release using a suspension object entry
         Wake_Up_Time := Wake_Up_Time + Milliseconds (100);
         Put_Line ("Timed SO release at " & Time_Str (Wake_Up_Time));
         Scheduler.Timed_Open (Wake_Up_Time);
         delay until Wake_Up_Time;
      end loop;
   end Main;

end RT_Example_A;
