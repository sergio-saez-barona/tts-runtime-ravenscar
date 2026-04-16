package Time_Stats is

   type Stats_Type is private;

   type Stats_Data_Array is array (Natural range <>) of Stats_Type;
   type Stats_Labels_Array is array (Natural range <>) of String (1 .. 5);

   procedure Update_Stats_Data
     (S : String; D : in out Stats_Type; Measurement : Duration);
   procedure Show_Stats_Data
     (Stats_Data : Stats_Data_Array; Stats_Labels : Stats_Labels_Array);
private

   type Stats_Type is record
      N   : Natural := 0;              --  Sample size so far
      Max : Duration := 0.0;            --  Maximum measured value
      Min : Duration := Duration'Last;  --  Minimum measured value
      Avg : Duration := 0.0;            --  Average
   end record;

end Time_Stats;
