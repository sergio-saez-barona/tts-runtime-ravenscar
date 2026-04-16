with Ada.Text_IO; use Ada.Text_IO;

package body Time_Stats is

   procedure Update_Stats_Data
     (S : String; D : in out Stats_Type; Measurement : Duration) is
   begin
      -- Put_Line
      --   (S
      --    & "> New measurement: "
      --    & Duration'Image (Measurement * 1_000_000.0) (1 .. 8)
      --    & " us");
      --  One more sample
      D.N := D.N + 1;
      --  Calculate average
      D.Avg := (D.Avg * (D.N - 1) + Measurement) / D.N;
      --  Update Max
      if Measurement > D.Max then
         D.Max := Measurement;
      end if;
      --  Update Min
      if Measurement < D.Min then
         D.Min := Measurement;
      end if;
   end Update_Stats_Data;

   procedure Show_Stats_Data
     (Stats_Data : Stats_Data_Array; Stats_Labels : Stats_Labels_Array)
   is
      --  Global max and min
      G_Max : Duration := 0.0;
      G_Min : Duration := Duration'Last;
   begin
      Put_Line ("----------- Times in microseconds ----------------------");
      Put_Line ("| Tr      Max         Avg         Min         Range    |");
      Put_Line ("--------------------------------------------------------");
      for I in Stats_Data'Range loop
         Put
           ("| "
            & Stats_Labels (I)
            & " :"
            & Duration'Image (Stats_Data (I).Max * 1_000_000.0) (1 .. 8)
            & "    "
            & Duration'Image (Stats_Data (I).Avg * 1_000_000.0) (1 .. 8)
            & "    "
            & Duration'Image (Stats_Data (I).Min * 1_000_000.0) (1 .. 8)
            & "    "
            & Duration'Image
                ((Stats_Data (I).Max - Stats_Data (I).Min) * 1_000_000.0)
                   (1 .. 8)
            & "  |");
         New_Line;
         if Stats_Data (I).Max > G_Max then
            G_Max := Stats_Data (I).Max;
         end if;
         if Stats_Data (I).Min < G_Min then
            G_Min := Stats_Data (I).Min;
         end if;
      end loop;
      Put_Line ("--------------------------------------------------------");
      Put_Line
        ("| Global:"
         & Duration'Image (G_Max * 1_000_000.0) (1 .. 8)
         & "     -          "
         & Duration'Image (G_Min * 1_000_000.0) (1 .. 8)
         & "    "
         & Duration'Image ((G_Max - G_Min) * 1_000_000.0) (1 .. 8)
         & "  |");
      Put_Line ("--------------------------------------------------------");
   end Show_Stats_Data;

end Time_Stats;
