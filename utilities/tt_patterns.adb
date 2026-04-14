with Ada.Real_Time;           use Ada.Real_Time;
with Ada.Exceptions;          use Ada.Exceptions;
with Ada.Task_Identification; use Ada.Task_Identification;
with Ada.Text_IO;             use Ada.Text_IO;

package body TT_Patterns is

   --------------------
   -- Simple_TT_Task --
   --------------------

   task body Simple_TT_Task is
   begin

      Task_State.Work_Id := Work_Id;

      if Synced_Init then
         TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);
      end if;

      Task_State.Initialize;

      loop
         TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);

         Task_State.Main_Code;
      end loop;
   exception
      when E : Storage_Error =>
         Put_Line
           ("Excepción en la tarea Simple_TT: "
            & Ada.Task_Identification.Image (Current_Task));
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end Simple_TT_Task;

   ---------------------------
   -- Initial_Final_TT_Task --
   ---------------------------

   task body Initial_Final_TT_Task is
   begin

      Task_State.Work_Id := Work_Id;

      if Synced_Init then
         TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);
      end if;

      Task_State.Initialize;

      loop
         TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);

         Task_State.Initial_Code;

         TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);

         Task_State.Final_Code;
      end loop;
   exception
      when E : Storage_Error =>
         Put_Line
           ("Excepción en la tarea Initial_Final_TT: "
            & Ada.Task_Identification.Image (Current_Task));
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end Initial_Final_TT_Task;

   -------------------------------------
   -- Initial_Mandatory_Final_TT_Task --
   -------------------------------------

   task body Initial_Mandatory_Final_TT_Task is
   begin

      Task_State.Work_Id := Work_Id;

      if Synced_Init then
         TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);
      end if;

      Task_State.Initialize;

      loop
         TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);

         Task_State.Initial_Code;

         TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);

         Task_State.Mandatory_Code;

         TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);

         Task_State.Final_Code;
      end loop;
   exception
      when E : Storage_Error =>
         Put_Line
           ("Excepción en la tarea Initial_Mandatory_Final_TT: "
            & Ada.Task_Identification.Image (Current_Task));
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end Initial_Mandatory_Final_TT_Task;

   ------------------------------------------
   -- InitialMandatorySliced_Final_TT_Task --
   ------------------------------------------

   task body InitialMandatorySliced_Final_TT_Task is
   begin

      Task_State.Work_Id := Work_Id;

      if Synced_Init then
         TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);
      end if;

      Task_State.Initialize;

      loop
         TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);

         Task_State.Initial_Code;

         TTS.Continue_Sliced;

         Task_State.Mandatory_Code;

         TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);

         Task_State.Final_Code;
      end loop;
   exception
      when E : Storage_Error =>
         Put_Line
           ("Excepción en la tarea InitialMandatorySliced_Final_TT: "
            & Ada.Task_Identification.Image (Current_Task));
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end InitialMandatorySliced_Final_TT_Task;

   ------------------------------------
   -- Iniitial_OptionalFinal_TT_Task --
   ------------------------------------

   task body Initial_OptionalFinal_TT_Task is
   begin

      Task_State.Work_Id := Work_Id;

      if Synced_Init then
         TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);
      end if;

      Task_State.Initialize;

      loop
         TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);

         Task_State.Initial_Code;

         if Task_State.Final_Is_Required then
            TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);

            Task_State.Final_Code;
         else
            TTS.Skip_Activation (Work_Id);
         end if;
      end loop;
   exception
      when E : Storage_Error =>
         Put_Line
           ("Excepción en la tarea Initial_OptionalFinal_TT: "
            & Ada.Task_Identification.Image (Current_Task));
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end Initial_OptionalFinal_TT_Task;

   ---------------------------
   -- Simple_Synced_ET_Task --
   ---------------------------

   task body Simple_Synced_ET_Task is
   begin

      Task_State.Work_Id := Work_Id;

      if Synced_Init then
         TTS.Wait_For_Sync (Work_Id, Task_State.Release_Time);
      end if;

      Task_State.Initialize;

      loop
         TTS.Wait_For_Sync (Work_Id, Task_State.Release_Time);

         Task_State.Main_Code;
      end loop;
   exception
      when E : Storage_Error =>
         Put_Line
           ("Excepción en la tarea Simple_Synced_ET: "
            & Ada.Task_Identification.Image (Current_Task));
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end Simple_Synced_ET_Task;

   ---------------------------
   -- Initial_Final_TT_Task --
   ---------------------------

   task body Initial_Final_Synced_ET_Task is
   begin

      Task_State.Work_Id := Work_Id;

      if Synced_Init then
         TTS.Wait_For_Sync (Work_Id, Task_State.Release_Time);
      end if;

      Task_State.Initialize;

      loop
         TTS.Wait_For_Sync (Work_Id, Task_State.Release_Time);

         Task_State.Initial_Code;

         TTS.Wait_For_Sync (Work_Id, Task_State.Release_Time);

         Task_State.Final_Code;
      end loop;
   exception
      when E : Storage_Error =>
         Put_Line
           ("Excepción en la tarea Initial_Final_Synced_ET: "
            & Ada.Task_Identification.Image (Current_Task));
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end Initial_Final_Synced_ET_Task;

   -----------------------------------------
   -- SyncedInitial_OptionalFinal_ET_Task --
   -----------------------------------------

   task body SyncedInitial_OptionalFinal_ET_Task is
   begin

      Task_State.Work_Id := Work_Id;

      if Synced_Init then
         TTS.Wait_For_Sync (Work_Id, Task_State.Release_Time);
      end if;

      Task_State.Initialize;

      loop
         TTS.Wait_For_Sync (Work_Id, Task_State.Release_Time);

         Task_State.Initial_Code;

         if Task_State.Final_Is_Required then
            TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);

            Task_State.Final_Code;
         else
            TTS.Skip_Activation (Work_Id);
         end if;
      end loop;
   end SyncedInitial_OptionalFinal_ET_Task;

end TT_Patterns;
