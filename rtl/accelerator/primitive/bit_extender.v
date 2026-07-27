module bit_extender #(
    parameter IPT_BIT = 0,
    parameter OPT_BIT = 0,
    parameter LSB_PAD = 0,
    parameter SIGNED  = 0
) (
    input  signed [IPT_BIT-1:0] i_din,
    output signed [OPT_BIT-1:0] o_dout
);
  generate
    if (SIGNED) begin
      assign o_dout = {
        {(OPT_BIT - IPT_BIT - LSB_PAD) {i_din[IPT_BIT-1]}}, i_din, {(LSB_PAD) {1'b0}}
      };
    end else begin
      assign o_dout = {{(OPT_BIT - IPT_BIT - LSB_PAD) {'b0}}, i_din, {(LSB_PAD) {1'b0}}};
    end
  endgenerate
endmodule
