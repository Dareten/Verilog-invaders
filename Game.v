`include "hvsync_generator.v"
`include "digits10.v"
 

module test_hvsync_top(clk, reset, hsync, vsync, rgb, switches_p1);

  input clk, reset;	// clock and reset signals (input)
  input [7:0] switches_p1;
  output hsync, vsync;	// H/V sync signals (output)
  output [2:0] rgb;	// RGB output (BGR order)
  wire display_on;	// display_on signal
  wire [8:0] hpos;	// 9-bit horizontal position
  wire [8:0] vpos;	// 9-bit vertical position

  wire playfield_gfx;
  reg [15:0] maze [0:27];
  wire [3:0] x = hpos[6:3];
  wire [4:0] y = vpos[7:3] - 2;
  assign playfield_gfx = maze[y][x];
  
  initial begin
    maze[0]  = 16'b1111111111111111;
    maze[1]  = 16'b1000000000000001;
    maze[2]  = 16'b1000000000000001;
    maze[3]  = 16'b1000000000000001;
    maze[4]  = 16'b1000000000000001;
    maze[5]  = 16'b1000000000000001;
    maze[6]  = 16'b1000000000000001;
    maze[7]  = 16'b1000000000000001;
    maze[8]  = 16'b1000000000000001;
    maze[9]  = 16'b1000000000000001;
    maze[10] = 16'b1000000000000001;
    maze[11] = 16'b1000000000000001;
    maze[12] = 16'b1000000000000001;
    maze[13] = 16'b1000000000000001;
    maze[14] = 16'b1000000000000001;
    maze[15] = 16'b1000000000000001;
    maze[16] = 16'b1000000000000001;
    maze[17] = 16'b1000000000000001;
    maze[18] = 16'b1000000000000001;
    maze[19] = 16'b1000000000000001;
    maze[20] = 16'b1000000000000001;
    maze[21] = 16'b1000000000000001;
    maze[22] = 16'b1000000000000001;
    maze[23] = 16'b1000000000000001;
    maze[24] = 16'b1000000000000001;
    maze[25] = 16'b1000000000000001;
    maze[26] = 16'b1000000000000001;
    maze[27] = 16'b1111111111111111;
  end
  
`define CMDWIDTH 8
`define PROGRAMSIZE 1024

`define INIT 0
`define MOVL 1
`define MOVR 2
`define FIRE 3
`define UP 4
`define DEL 5
`define JMP 6


`define DEF_MAZE 16'b1000000000000001

reg [$clog2(`PROGRAMSIZE) - 1 : 0] pc, new_pc;
reg [`CMDWIDTH - 1 : 0] Program [0 :  `PROGRAMSIZE - 1];

wire [3:0] command_current;
assign command_current = Program[pc][7:4];
wire [3:0] op;
assign op = Program[pc][3:0];


  
reg fire;
reg del;
reg sync;
reg fire_l;
reg [4:0] left_pos;
reg [3:0] dota2;
reg [19:0] divider;
reg [15:0] ship [0:2];

integer i, fire_reload;
  
initial
begin
  fire_reload = 0;
  new_pc = 0;
  pc = 0;	
  // Инициализация памяти программы
  for(i = 0; i < `PROGRAMSIZE; i = i + 1)
  Program[i] = 8'b00000000;
  Program[0] = 8'h00; // INIT
  Program[1] = 8'h10; // MOVL
  Program[2] = 8'h20; // MOVR
  Program[3] = 8'h30; // FIRE
  Program[4] = 8'h40; // UP
  Program[5] = 8'h50; // DEL
  Program[6] = 8'h61; // JMP 1	
end	

  
//Определение логики установки флагов
always@(posedge clk) 
begin
  divider <= divider + 1;
  if (divider == 20'b10000000000000000000) begin
    sync    <= 1;
    if (fire_reload < 5) begin
      fire_reload <= fire_reload + 1;
    end
    else begin
      fire <= 1;
      fire_reload <= 0;
    end
  end
end
  

  
  initial begin
    fire_l   = 1;
    left_pos = 6;
    del      = 0;
    ship[0]  = 16'b1000000110000001;
    ship[1]  = 16'b1000001111000001;
    ship[2]  = 16'b1000001001000001;
  end
  

  
  always@(posedge clk) begin
  case(command_current)
    `INIT: begin // Инициализация нашего корабля и корабля врага
      if (switches_p1[4]) begin
        maze[1]  <= ship[0];
        maze[2]  <= ship[0];
        maze[3]  <= ship[1];
        maze[4]  <= ship[2];
        maze[5]  <= ship[2];
        maze[23] <= 16'b1000000110000001;
        maze[24] <= 16'b1000001111000001;
        maze[25] <= 16'b1000001001000001;
        pc <= pc + 1;
      end
    end 

    `FIRE: begin // Выпуск снаряда
      if (switches_p1[2] && fire)
        if (fire_l) begin
          maze[22][left_pos + 1] <= 1;
          fire_l <= 0;
          fire   <= 0;
        end
        else begin
          maze[22][left_pos + 2] <= 1;
          fire_l <= 1;
          fire   <= 0;
        end
      pc <= pc + 1;
    end

    `UP: begin // Движение снаряда
      if (sync) begin
        maze[6:21] <= maze[7:22];
        maze[22]   <= 16'b1000000000000001;
        if (!del && ((maze[5][9:6] & maze[6][9:6] ) != 4'b0000))
          del <= 1;
        maze[5]    <= maze[6] | ship[2];
        maze[4]    <= maze[5] | ship[2];
        if (!del && ((maze[4][9:6] & maze[3][9:6]) != ship[2][9:6]))
          del <= 1;
        maze[3]    <= maze[4] | ship[1];
        maze[2]    <= (maze[3] | ship[0]) & 16'b1111110110111111;
        maze[1]    <= (maze[2] | ship[0]) & 16'b1111110110111111;
        sync         <= 0;
      end
      pc <= pc + 1;
    end

    `MOVR: begin // Движение нашего корабля вправо
      if (switches_p1[1] && sync) begin
        if (left_pos < 11) begin
          left_pos <= left_pos + 1;
          maze[23][14:2] <= maze[23][13:1];
          maze[24][14:2] <= maze[24][13:1];
          maze[25][14:2] <= maze[25][13:1];
          maze[23][1] <= 1'b0;
          maze[24][1] <= 1'b0;
          maze[25][1] <= 1'b0;
        end
      end
      pc <= pc + 1;
    end
    
    `MOVL: begin // Движение нашего корабля слево
      if (switches_p1[0] && sync) begin
        if (left_pos > 1) begin
          left_pos <= left_pos - 1;
          maze[23][13:1] <= maze[23][14:2];
          maze[24][13:1] <= maze[24][14:2];
          maze[25][13:1] <= maze[25][14:2];
          maze[23][14] <= 1'b0;
          maze[24][14] <= 1'b0;
          maze[25][14] <= 1'b0;
        end
      end
      pc <= pc + 1;
    end

    `JMP: begin // Безусловный прыжок к первой команде
      pc <= {6'b000000, op};
    end

    `DEL: begin // Удаление вражеского корабля при попадании
      if (del) begin
        ship[0] <= 16'b1000000000000001;
        ship[1] <= 16'b1000000000000001;
        ship[2] <= 16'b1000000000000001;
        del <= 0;
      end
      pc <= pc + 1;
    end
  endcase
  
end
  

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(0),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos)
  );

  wire r = 0;
  wire g = display_on & ((playfield_gfx & vpos > 23 & vpos < 232 & hpos > 7 & hpos < 120));
  wire b = display_on & playfield_gfx & hpos < 129;
  
  assign rgb = {b,g,r};
endmodule
