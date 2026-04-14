with Ada.Real_Time; use Ada.Real_Time;
with System;
with XAda.Dispatching.TTS;
with TT_Mixed_Criticality; use TT_Mixed_Criticality;
with TT_Utilities;

generic
   Number_Of_Works : Positive := 1;
   TT_Priority : System.Priority := System.Priority'Last;
package TTS_Plan_E is
   subtype Criticality_Levels is No_Criticality_Levels;

   package TTS is new XAda.Dispatching.TTS
     (Criticality_Levels, Number_Of_Works, TT_Priority);
   package TTU is new TT_Utilities (TTS);
   use TTU;

   ms : constant Time_Span := Milliseconds (1);
   us : constant Time_Span := Microseconds (1);
   zero : constant Time_Span := Time_Span_Zero;

   --  The TT plan
   Plan_E : aliased TTS.Time_Triggered_Plan :=
     (-- 0-10
      --  Work 1 A. Check E->I, E->R
      TT_Slot (Empty,                10 * ms   ),
      -- 10-20
      TT_Slot (Initial,              10 * ms, 1),
      -- 20-30
      TT_Slot (Empty,                10 * ms   ),
      -- 30-40
      TT_Slot (Final,                10 * ms, 1),
      -- 40-50
      --  Work 2 A. Check E->IS, E->S
      TT_Slot (Empty,                10 * ms   ),
      -- 50-60
      TT_Slot (Initial_Sync,         10 * ms, 2),
      -- 60-70
      TT_Slot (Empty,                10 * ms   ),
      -- 70-80
      TT_Slot (Sync,                 10 * ms, 2),
      -- 80-90
      --  Work 3 A. Check E->IC + padding
      TT_Slot (Empty,                10 * ms   ),
      -- 90-100
      TT_Slot (Initial_Continuation, 10 * ms, 3,
               Paddings => (Normal => 50 * us)),
      -- 100-110
      TT_Slot (Empty,                10 * ms   ),
      -- 110-120
      TT_Slot (Final,                10 * ms, 3),
      -- 120-130
      --  Work 4 A. Check E->C + padding
      TT_Slot (Empty,                10 * ms   ),
      -- 130-140
      TT_Slot (Initial,              10 * ms, 4),
      -- 140-150
      TT_Slot (Empty,                10 * ms   ),
      -- 150-160
      TT_Slot (Continuation,         10 * ms, 4,
               Paddings => (Normal => 50 * us)),
      -- 160-170
      TT_Slot (Empty,                10 * ms   ),
      -- 170-180
      TT_Slot (Final,                10 * ms, 4),
      -- 180-190
      --  Work 1 B. Check H->I, H->R
      TT_Slot (Empty,                10 * ms   ),
      -- 190-200
      TT_Slot (Initial,              10 * ms, 5,
               Paddings => (Normal => 50 * us)),
      -- 200-210
      TT_Slot (Initial,              10 * ms, 1),
      -- 210-220
      TT_Slot (Final,                10 * ms, 5),
      -- 220-230
      TT_Slot (Empty,                10 * ms   ),
      -- 230-240
      TT_Slot (Initial,              10 * ms, 5,
               Paddings => (Normal => 50 * us)),
      -- 240-250
      TT_Slot (Final,                10 * ms, 1),
      -- 250-260
      TT_Slot (Final,                10 * ms, 5),
      -- 260-270
      --  Work 2 B. Check H->IS, H->S
      TT_Slot (Empty,                10 * ms   ),
      -- 270-280
      TT_Slot (Initial,              10 * ms, 5,
               Paddings => (Normal => 50 * us)),
      -- 280-290
      TT_Slot (Initial_Sync,         10 * ms, 2),
      -- 290-300
      TT_Slot (Final,                10 * ms, 5),
      -- 300-310
      TT_Slot (Empty,                10 * ms   ),
      -- 310-320
      TT_Slot (Initial,              10 * ms, 5,
               Paddings => (Normal => 50 * us)),
      -- 320-330
      TT_Slot (Sync,                 10 * ms, 2),
      -- 330-340
      TT_Slot (Final,                10 * ms, 5),
      -- 340-350
      --  Work 3 B. Check H->IC + padding
      TT_Slot (Initial,              10 * ms, 5,
               Paddings => (Normal => 50 * us)),
      -- 350-360
      TT_Slot (Initial_Continuation, 10 * ms, 3,
               Paddings => (Normal => 50 * us)),
      -- 360-370
      TT_Slot (Final,                10 * ms, 5),
      -- 370-380
      TT_Slot (Empty,                10 * ms   ),
      -- 380-390
      TT_Slot (Final,                10 * ms, 3),
      -- 390-400
      --  Work 4 B. Check H->C + padding
      TT_Slot (Empty,                10 * ms   ),
      -- 400-410
      TT_Slot (Initial,              10 * ms, 4),
      -- 410-420
      TT_Slot (Empty,                10 * ms   ),
      -- 420-430
      TT_Slot (Initial,              10 * ms, 5,
               Paddings => (Normal => 50 * us)),
      -- 430-440
      TT_Slot (Continuation,         10 * ms, 4,
               Paddings => (Normal => 50 * us)),
      -- 440-450
      TT_Slot (Final,                10 * ms, 5),
      -- 450-460
      TT_Slot (Empty,                10 * ms   ),
      -- 460-470
      TT_Slot (Final,                10 * ms, 4),
      -- 470-480
      --  Work 6. Report task
      TT_Slot (Empty,                10 * ms   ),
      -- 480-490
      TT_Slot (Initial,              10 * ms, 6)
      );

end TTS_Plan_E;
