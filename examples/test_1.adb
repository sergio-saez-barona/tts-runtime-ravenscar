with Ada.Real_Time;               use Ada.Real_Time;
with System;
with Ada.Real_Time.Timing_Events; use Ada.Real_Time.Timing_Events;
with Ada.Text_IO;                 use Ada.Text_IO;

package body Test_1 is

   -- 1. Un evento de tiempo simple
   protected type Timer_Handler
     with Priority => System.Interrupt_Priority'Last
   is
      procedure Handle_Event (Event : in out Timing_Event);
   end Timer_Handler;

   protected body Timer_Handler is
      procedure Handle_Event (Event : in out Timing_Event) is
      begin
         Put_Line ("Timing Event");
      end Handle_Event;
   end Timer_Handler;

   Handler : Timer_Handler;
   Event   : Timing_Event;

   -- 2. Una tarea con pila controlada
   task type Test_Task with Storage_Size => 4096;

   task body Test_Task is
      Next_Time : Time := Clock;
      Counter   : Natural := 0;
   begin
      loop
         Next_Time := Next_Time + Milliseconds (500);
         Counter := Counter + 1;
         Put_Line ("Task: " & Counter'Image);
         delay until Next_Time;
      end loop;
   end Test_Task;

   Worker : Test_Task;

   procedure Main is
      Counter : Natural := 1;
   begin
      -- Programamos el evento para dentro de 1 segundo
      Event.Set_Handler (Clock + Seconds (5), Handler.Handle_Event'Access);

      loop
         Counter := Counter + 1;
         Put_Line ("Clock: " & Counter'Image);
         delay until Clock + Seconds (1);
      end loop;
   end Main;

end Test_1;
