with Ada.Real_Time;  use Ada.Real_Time;
with Ada.Exceptions; use Ada.Exceptions;
with Ada.Text_IO;    use Ada.Text_IO;

package body TT_Patterns is

   --------------------
   -- Simple_TT_Task --
   --------------------

   task body Simple_TT_Task is
      -- These constants cannot be changed after initialization,
      --  so we can avoid reading the Task_State record multiple times
      Criticality_Level : constant TTS.Criticality_Levels :=
        Task_State.Criticality_Level;
      Is_Cancellable    : constant Boolean := Task_State.Is_Cancellable;
   begin
      Task_State.Work_Id := Work_Id;

      TTS.Work_Initialization (Work_Id, Criticality_Level, Is_Cancellable);

      if Task_State.Synced_Init then
         TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);
      end if;

      Task_State.Initialize;

      loop
         declare
            Rearming : Boolean := False;
         begin
            loop
               TTS.Wait_For_Activation (Work_Id, Task_State.Release_Time);

               Task_State.Main_Code;
            end loop;
         exception
            when E : others =>
               -- Handle cancellation, if it's not a cancellation exception, re-raise it
               if Ada.Exceptions.Exception_Identity (E)
                 = TTS.Work_Cancelled'Identity
               then
                  Task_State.Cancellation_Code (Rearming);
                  if not Rearming then
                     exit; -- Task will terminate

                  else
                     -- Task will be rearmed, we need to call Work_Initialization again
                     TTS.Work_Initialization
                       (Work_Id, Criticality_Level, Is_Cancellable);
                  end if;
               else
                  -- Re-elevar si no es la que buscamos
                  raise;
               end if;

         end;
      end loop;
   exception
      when E : others =>
         Put_Line ("Exception in Simple_TT: " & Work_Id'Image);
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end Simple_TT_Task;

   ---------------------------
   -- Initial_Final_TT_Task --
   ---------------------------

   task body Initial_Final_TT_Task is
      -- These constants cannot be changed after initialization,
      --  so we can avoid reading the Task_State record multiple times
      Criticality_Level : constant TTS.Criticality_Levels :=
        Task_State.Criticality_Level;
      Is_Cancellable    : constant Boolean := Task_State.Is_Cancellable;
   begin

      Task_State.Work_Id := Work_Id;

      TTS.Work_Initialization (Work_Id, Criticality_Level, Is_Cancellable);

      if Task_State.Synced_Init then
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
      when E : others =>
         Put_Line ("Exception in Initial_Final_TT: " & Work_Id'Image);
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end Initial_Final_TT_Task;

   -------------------------------------
   -- Initial_Mandatory_Final_TT_Task --
   -------------------------------------

   task body Initial_Mandatory_Final_TT_Task is
      -- These constants cannot be changed after initialization,
      --  so we can avoid reading the Task_State record multiple times
      Criticality_Level : constant TTS.Criticality_Levels :=
        Task_State.Criticality_Level;
      Is_Cancellable    : constant Boolean := Task_State.Is_Cancellable;
   begin

      Task_State.Work_Id := Work_Id;

      TTS.Work_Initialization
        (Work_Id, Task_State.Criticality_Level, Task_State.Is_Cancellable);

      if Task_State.Synced_Init then
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
      when E : others =>
         Put_Line
           ("Exception in Initial_Mandatory_Final_TT: " & Work_Id'Image);
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end Initial_Mandatory_Final_TT_Task;

   ------------------------------------------
   -- InitialMandatorySliced_Final_TT_Task --
   ------------------------------------------

   task body InitialMandatorySliced_Final_TT_Task is
      -- These constants cannot be changed after initialization,
      --  so we can avoid reading the Task_State record multiple times
      Criticality_Level : constant TTS.Criticality_Levels :=
        Task_State.Criticality_Level;
      Is_Cancellable    : constant Boolean := Task_State.Is_Cancellable;
   begin

      Task_State.Work_Id := Work_Id;

      TTS.Work_Initialization
        (Work_Id, Task_State.Criticality_Level, Task_State.Is_Cancellable);

      if Task_State.Synced_Init then
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
      when E : others =>
         Put_Line
           ("Exception in InitialMandatorySliced_Final_TT: " & Work_Id'Image);
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end InitialMandatorySliced_Final_TT_Task;

   ------------------------------------
   -- Iniitial_OptionalFinal_TT_Task --
   ------------------------------------

   task body Initial_OptionalFinal_TT_Task is
      -- These constants cannot be changed after initialization,
      --  so we can avoid reading the Task_State record multiple times
      Criticality_Level : constant TTS.Criticality_Levels :=
        Task_State.Criticality_Level;
      Is_Cancellable    : constant Boolean := Task_State.Is_Cancellable;
   begin

      Task_State.Work_Id := Work_Id;

      TTS.Work_Initialization
        (Work_Id, Task_State.Criticality_Level, Task_State.Is_Cancellable);

      if Task_State.Synced_Init then
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
      when E : others =>
         Put_Line ("Exception in Initial_OptionalFinal_TT: " & Work_Id'Image);
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end Initial_OptionalFinal_TT_Task;

   ---------------------------
   -- Simple_Synced_ET_Task --
   ---------------------------

   task body Simple_Synced_ET_Task is
      -- These constants cannot be changed after initialization,
      --  so we can avoid reading the Task_State record multiple times
      Criticality_Level : constant TTS.Criticality_Levels :=
        Task_State.Criticality_Level;
      Is_Cancellable    : constant Boolean := Task_State.Is_Cancellable;
   begin

      Task_State.Work_Id := Work_Id;

      TTS.Work_Initialization
        (Work_Id, Task_State.Criticality_Level, Task_State.Is_Cancellable);

      if Task_State.Synced_Init then
         TTS.Wait_For_Sync (Work_Id, Task_State.Release_Time);
      end if;

      Task_State.Initialize;

      loop
         TTS.Wait_For_Sync (Work_Id, Task_State.Release_Time);

         Task_State.Main_Code;
      end loop;
   exception
      when E : others =>
         Put_Line ("Exception in Simple_Synced_ET: " & Work_Id'Image);
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end Simple_Synced_ET_Task;

   ---------------------------
   -- Initial_Final_TT_Task --
   ---------------------------

   task body Initial_Final_Synced_ET_Task is
      -- These constants cannot be changed after initialization,
      --  so we can avoid reading the Task_State record multiple times
      Criticality_Level : constant TTS.Criticality_Levels :=
        Task_State.Criticality_Level;
      Is_Cancellable    : constant Boolean := Task_State.Is_Cancellable;
   begin

      Task_State.Work_Id := Work_Id;

      TTS.Work_Initialization
        (Work_Id, Task_State.Criticality_Level, Task_State.Is_Cancellable);

      if Task_State.Synced_Init then
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
      when E : others =>
         Put_Line ("Exception in Initial_Final_Synced_ET: " & Work_Id'Image);
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end Initial_Final_Synced_ET_Task;

   -----------------------------------------
   -- SyncedInitial_OptionalFinal_ET_Task --
   -----------------------------------------

   task body SyncedInitial_OptionalFinal_ET_Task is
      -- These constants cannot be changed after initialization,
      --  so we can avoid reading the Task_State record multiple times
      Criticality_Level : constant TTS.Criticality_Levels :=
        Task_State.Criticality_Level;
      Is_Cancellable    : constant Boolean := Task_State.Is_Cancellable;
   begin

      Task_State.Work_Id := Work_Id;

      TTS.Work_Initialization
        (Work_Id, Task_State.Criticality_Level, Task_State.Is_Cancellable);

      if Task_State.Synced_Init then
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
   exception
      when E : others =>
         Put_Line
           ("Exception in SyncedInitial_OptionalFinal_ET_Task: "
            & Work_Id'Image);
         Put_Line (Exception_Information (E));
         Put_Line (Exception_Message (E));
   end SyncedInitial_OptionalFinal_ET_Task;

end TT_Patterns;
