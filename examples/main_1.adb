with Test_1;
with Ada.Real_Time;
with System;

procedure Main_1
  with Priority => System.Priority'First
is
begin
   Test_1.Main;
   delay until Ada.Real_Time.Time_Last;
end Main_1;
