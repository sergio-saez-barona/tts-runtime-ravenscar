with Ada.Real_Time; use Ada.Real_Time;

package body TT_Utilities is
   use TTS;

   ---------------------------------
   --  Constructors of Time_Slots --
   ---------------------------------

   --  Auxiliary function for constructing slots --
   function TT_Slot
     (Kind           : Slot_Type;
      Slot_Duration  : Time_Span;
      Slot_Id        : Positive := No_Id;
      Work_Durations : TTS.Time_Span_Array := (others => TTS.Full_Slot_Size);
      Paddings       : TTS.Time_Span_Array := (others => Time_Span_Zero))
      return TTS.Any_Time_Slot
   is
      New_Slot : TTS.Any_Time_Slot;
   begin
      case Kind is
         when Empty       =>
            New_Slot := new TTS.Empty_Slot;

         when Mode_Change =>
            New_Slot := new TTS.Mode_Change_Slot;

         when others      =>
            declare
               WS_Type : constant TTS.Work_Slot_Type :=
                 (case Kind is
                    when Initial_Continuation | Continuation =>
                      TTS.Continuation,
                    when Initial_Sync | Sync                 => TTS.Sync,
                    when others                              => TTS.Regular);
            begin
               New_Slot := new TTS.Work_Slot (WS_Type);
            end;
      end case;

      Set_TT_Slot
        (New_Slot, Kind, Slot_Duration, Slot_Id, Work_Durations, Paddings);

      return New_Slot;
   end TT_Slot;

   procedure Set_Work_Slot
     (Slot           : TTS.Any_Work_Slot;
      Slot_Duration  : Time_Span;
      Slot_Id        : Positive := No_Id;
      Is_Initial     : Boolean := False;
      Is_Optional    : Boolean := False;
      Work_Durations : TTS.Time_Span_Array := (others => TTS.Full_Slot_Size);
      Paddings       : TTS.Time_Span_Array := (others => Time_Span_Zero)) is
   begin
      Slot.Slot_Size := Slot_Duration;

      begin
         Slot.Work_Id := TTS.TT_Work_Id (Slot_Id);
      exception
         when Constraint_Error =>
            raise TTS.Plan_Error with "Invalid work Id" & Slot_Id'Image;
      end;

      Slot.Is_Initial := Is_Initial;
      Slot.Is_Optional := Is_Optional;

      if Slot.Work_Type /= TTS.Sync then
         for I in Work_Durations'Range loop
            if (Work_Durations (I) = TTS.Full_Slot_Size) then
               Slot.Work_Sizes (I) := Slot_Duration;
            elsif Work_Durations (I) <= Slot_Duration then
               Slot.Work_Sizes (I) := Work_Durations (I);
            else
               raise TTS.Plan_Error
                 with ("Invalid work duration (" & I'Image & ")");
            end if;

            if Paddings (I) <= Slot.Work_Sizes (I) then
               Slot.Padding_Sizes (I) := Paddings (I);
            else
               raise TTS.Plan_Error
                 with ("Invalid padding duration (" & I'Image & ")");
            end if;

         end loop;
      end if;

   end Set_Work_Slot;

   procedure Set_TT_Slot
     (Slot           : TTS.Any_Time_Slot;
      Kind           : Slot_Type;
      Slot_Duration  : Time_Span;
      Slot_Id        : Positive := No_Id;
      Work_Durations : TTS.Time_Span_Array := (others => TTS.Full_Slot_Size);
      Paddings       : TTS.Time_Span_Array := (others => Time_Span_Zero))
   is
      Is_Initial  : constant Boolean :=
        (case Kind is
           when Initial | Initial_Continuation | Initial_Sync => True,
           when others                                        => False);
      Is_Optional : constant Boolean := (Kind = Optional);
   begin
      case Kind is
         when Empty       =>
            if Slot.all not in TTS.Empty_Slot'Class then
               raise TTS.Plan_Error with "Provided slot is not an Empty slot";
            end if;

            Slot.Slot_Size := Slot_Duration;

         when Mode_Change =>
            if Slot.all not in TTS.Mode_Change_Slot'Class then
               raise TTS.Plan_Error
                 with "Provided slot is not a Mode Change slot";
            end if;

            Slot.Slot_Size := Slot_Duration;

         when others      =>
            if Slot.all not in TTS.Work_Slot'Class then
               raise TTS.Plan_Error with "Provided slot is not a work slot";
            end if;

            Set_Work_Slot
              (TTS.Any_Work_Slot (Slot),
               Slot_Duration,
               Slot_Id,
               Is_Initial,
               Is_Optional,
               Work_Durations,
               Paddings);
      end case;

   end Set_TT_Slot;

end TT_Utilities;
