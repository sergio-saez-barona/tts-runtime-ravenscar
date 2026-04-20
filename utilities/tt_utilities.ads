with Ada.Real_Time; use Ada.Real_Time;

with XAda.Dispatching.TTS;

generic
   with package TTS is new XAda.Dispatching.TTS (<>);

package TT_Utilities
is

   ---------------------------------------------
   --  Time_Slot kinds for building TT plans  --
   ---------------------------------------------
   type Slot_Type is
     (Empty,
      Mode_Change,
      Initial,
      Initial_Continuation,
      Initial_Sync,
      Regular,
      Continuation,
      Final,
      Terminal,
      Optional,
      Sync);

   No_Id : Positive := Positive'Last;

   ---------------------------------------
   --  Time_Slot constructor functions  --
   ---------------------------------------
   function TT_Slot
     (Kind           : Slot_Type;
      Slot_Duration  : Time_Span;
      Slot_Id        : Positive := No_Id;
      Work_Durations : TTS.Time_Span_Array := (others => TTS.Full_Slot_Size);
      Paddings       : TTS.Time_Span_Array := (others => Time_Span_Zero))
      return TTS.Any_Time_Slot
             --  Make sure the Slot_Duration is non-negative and
             --  the value of Slot_Id is consistent with the kind of slot
   with
     Pre =>
       (Slot_Duration >= Time_Span_Zero
        and then (case Kind is
                    when Empty .. Mode_Change => (Slot_Id = No_Id),
                    when Initial .. Sync =>
                      (Slot_Id >= Positive (TTS.TT_Work_Id'First)
                       and Slot_Id <= Positive (TTS.TT_Work_Id'Last))));

   ---------------------------------
   --  Time_Slot setter procedure --
   ---------------------------------
   procedure Set_TT_Slot
     (Slot           : TTS.Any_Time_Slot;
      Kind           : Slot_Type;
      Slot_Duration  : Time_Span;
      Slot_Id        : Positive := No_Id;
      Work_Durations : TTS.Time_Span_Array := (others => TTS.Full_Slot_Size);
      Paddings       : TTS.Time_Span_Array := (others => Time_Span_Zero))
     --  Make sure the Slot_Duration is non-negative and
     --  the value of Slot_Id is consistent with the kind of slot
   with
     Pre =>
       (Slot_Duration >= Time_Span_Zero
        and then (case Kind is
                    when Empty .. Mode_Change => (Slot_Id = No_Id),
                    when Initial .. Sync =>
                      (Slot_Id >= Positive (TTS.TT_Work_Id'First)
                       and Slot_Id <= Positive (TTS.TT_Work_Id'Last))));

end TT_Utilities;
