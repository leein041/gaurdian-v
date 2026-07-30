

`include "defines.vh"
`include "network_config.vh"
module scheduler #(
    localparam FBUF_DEPTH = `MAX_FILTER_GROUP_NUM * `MAX_IPT_AREA,
    localparam WGT_BANK_DEPTH = `MAX_CHANNEL * `CONV_3X3_AREA
) (
    input                                        i_clk,
    input                                        i_rstn,
    // bias loader  
    output [   `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] o_bl_req_addr,
    // bias reader 
    output [ `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] o_br_read_addr,
    // weight loader 
    output [    `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] o_wl_req_addr,
    // weight reader 
    output [    `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] o_wr_read_addr,
    // tile loader  
    output [        `CLOG2_SAFE(FBUF_DEPTH)-1:0] o_img_base_addr,
    // tile reader 
    output [`CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] o_tr_read_addr,
    //
    input                                        i_nxt_filt_grp,
    input                                        i_nxt_tile_col,
    input                                        i_nxt_tile_row,
    input                                        i_nxt_ch_grp
);
  // ====================== parmeter =======================   
  integer                                                i;
  // ====================== wire =========================== 
  wire                                                   w_lyr_vld;
  wire    [              `OPT_BIT*`MAX_GROUP_FILTER-1:0] w_lyr_dat;
  // ====================== reg ============================   
  // bias loader (BL) 
  reg     [            `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] r_bl_base_addr;
  reg     [            `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] r_bl_req_addr;
  // bias reader (BR) 
  reg     [          `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] r_br_base_addr;
  reg     [          `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] r_br_read_addr;
  // weight loader (WL) 
  reg     [`CLOG2_SAFE(`MAX_CHANNEL*`CONV_3X3_AREA) : 0] r_wl_addr_stride;
  reg     [             `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] r_wl_base_addr;
  reg     [             `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] r_wl_req_addr;
  // weight reader (WR) 
  reg     [             `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] r_wr_base_addr;
  reg     [             `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] r_wr_read_addr;
  // tile loader (TL) 
  reg     [                 `CLOG2_SAFE(FBUF_DEPTH)-1:0] r_tl_base_addr;
  reg     [              `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_tl_row_base_addr;
  reg     [              `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_tl_row_stride;
  reg     [                 `CLOG2_SAFE(FBUF_DEPTH) : 0] r_tl_ch_base_addr;
  reg     [              `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_tr_col_stride;
  reg     [              `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_tl_ch_stride;
  // tile reader (TR) 
  reg     [         `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] r_tr_read_addr;
  // DDR
  reg                                                    r_obuf_we;
  reg     [             `OPT_BIT* `MAX_GROUP_FILTER-1:0] r_obuf_wdat;
  reg     [               `CLOG2_SAFE(`MAX_TILE_AREA):0] r_obuf_pix_col;
  reg     [                 `CLOG2_SAFE(FBUF_DEPTH) : 0] r_obuf_pix_row;
  reg     [                 `CLOG2_SAFE(FBUF_DEPTH) : 0] r_obuf_tile_row;
  reg     [                 `CLOG2_SAFE(FBUF_DEPTH) : 0] r_obuf_tile_col;
  reg     [              `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_obuf_tile_row_stride;
  reg     [                 `CLOG2_SAFE(FBUF_DEPTH) : 0] r_obuf_ch_base_addr;
  reg     [                 `CLOG2_SAFE(FBUF_DEPTH) : 0] r_obuf_ch_stride;
  reg     [                 `CLOG2_SAFE(FBUF_DEPTH)-1:0] r_obuf_waddr;
  // ====================== assign =========================     
  
          r_tl_base_addr == r_tl_row_base_addr + r_tl_ch_base_addr;
           

        NEXT_FILTER_GRP: begin    
            r_bl_base_addr <= r_bl_base_addr + `MAX_GROUP_FILTER;
            r_wl_base_addr <= r_wl_base_addr + r_wl_addr_stride; 
          r_wr_base_addr     <= 'd0;
          r_tl_ch_base_addr  <= 'd0;   
          r_tl_row_base_addr <= 'd0;  
        end

        NEXT_TILE: begin  
          r_wr_base_addr    <= 'd0;
          r_tl_ch_base_addr <= 'd0; 

          if (r_tile_x_cnt < r_tile_num_x - 1) begin
            r_tile_x_cnt <= r_tile_x_cnt + 'd1;
            r_nxt_org_x <= r_nxt_org_x + r_tile_side;
            r_obuf_tile_col <= r_obuf_tile_col + r_tile_side;
          end else begin
            r_tile_x_cnt <= 'd0;
            r_nxt_org_x <= 0;
            r_obuf_tile_col <= 0;
            if (r_tile_y_cnt < r_tile_num_y - 1) begin 
              r_tl_row_base_addr <= r_tl_row_base_addr + r_tl_row_stride;
            end
          end
        end

        NEXT_CHANNEL_GRP: begin
          r_lyr_clr <= 'b1;
          if (r_ch_grp_idx < r_ch_grp_num - 1) begin
            r_ch_grp_idx      <= r_ch_grp_idx + 'd1;
            r_ch_idx          <= r_ch_idx + `MAX_GROUP_CHANNEL;
            r_wr_base_addr    <= r_wr_base_addr + `MAX_GROUP_CHANNEL * `CONV_3X3_AREA;
            r_tl_ch_base_addr <= r_tl_ch_base_addr + r_tl_ch_stride;
          end
        end

        NEXT_LAYER: begin
          if (r_lyr_idx != `LAYER_NUM - 1) begin
            r_lyr_idx          <= r_lyr_idx + 'd1;
            r_lyr_clr          <= 'b1;
            r_fbuf_switch      <= 'b1;
            // init filt 
            r_filt_grp_idx     <= 'd0;
            r_filt_idx         <= 'd0;
            r_bl_base_addr     <= 'd0;
            r_wl_base_addr     <= 'd0;
            // init ddr
            r_obuf_ch_base_addr <= 'd0;
            r_obuf_pix_row      <= 'd0;
            r_obuf_pix_col      <= 'd0;
            r_obuf_tile_col     <= 'd0;
            r_obuf_tile_row     <= 'd0;
            // init tile
            r_nxt_org_x        <= 'd0;
            r_nxt_org_y        <= 'd0;
            r_tile_x_cnt       <= 'd0;
            r_tile_y_cnt       <= 'd0;
            r_tl_row_base_addr <= 'd0;
            r_tile_idx         <= 'd0;
            // init ch
            r_wr_base_addr     <= 'd0;
            r_tl_ch_base_addr  <= 'd0;
            r_ch_grp_idx       <= 'd0;
            r_ch_idx           <= 'd0;
          end
        end

        DONE: begin
          r_dn <= 'b1;
        end

        default: ;
      endcase
    end
  end

  // ====================== module ========================= 
endmodule
