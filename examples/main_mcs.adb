with Ada.Exceptions; use Ada.Exceptions;
with Ada.Real_Time;
with Ada.Text_IO;    use Ada.Text_IO;
with System;
with TTS_Example_MCS;

procedure Main_MCS with Priority => System.Priority'First is
begin
   TTS_Example_MCS.Main;
   delay until Ada.Real_Time.Time_Last;
exception
   when E : others =>
      Put_Line (Exception_Message (E));
end Main_MCS;
