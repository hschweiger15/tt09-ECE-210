`default_nettype none

module tt_um_lsnn_hschweig #(  
    parameter MEMBRANE_WIDTH = 12,
    parameter INPUT_WIDTH = 8,
    parameter DECAY_FACTOR = 4'b0010,
    parameter ADAPTATION_RATE = 4'b0001,
    parameter REFRACTORY_PERIOD = 4'd3,
    parameter THRESHOLD_BASE = 12'd100
)(
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    assign uio_oe = 8'hFF;  // All outputs

    // Internal registers
    reg [MEMBRANE_WIDTH-1:0] membrane_potential;
    reg [MEMBRANE_WIDTH-1:0] threshold;
    reg [MEMBRANE_WIDTH-1:0] adaptation;
    reg [3:0] refractory_counter;
    reg [6:0] spike_count;
    reg spike_out;

    // Control signals
    wire learning_enable = uio_in[0];
    
    // Spike condition
    wire threshold_crossed = (membrane_potential >= threshold);
    wire can_spike = (refractory_counter == 0);
    wire spike_condition = threshold_crossed && can_spike;

    // Next membrane potential calculation
    wire [MEMBRANE_WIDTH-1:0] decay = membrane_potential >> DECAY_FACTOR;
    wire [MEMBRANE_WIDTH-1:0] next_membrane = 
        spike_condition ? 0 : // Reset if spiking
        (refractory_counter > 0) ? membrane_potential : // Hold during refractory
        (membrane_potential - decay + {4'b0, ui_in}); // Normal update

    // Output assignments
    assign uo_out = {refractory_counter != 0, membrane_potential[11:5]};
    assign uio_out = {spike_count, spike_out};

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            membrane_potential <= 0;
            threshold <= THRESHOLD_BASE;
            adaptation <= 0;
            refractory_counter <= 0;
            spike_count <= 0;
            spike_out <= 0;
        end else begin
            // Update membrane potential
            membrane_potential <= next_membrane;
            
            // Update refractory counter
            if (spike_condition) begin
                refractory_counter <= REFRACTORY_PERIOD;
            end else if (refractory_counter > 0) begin
                refractory_counter <= refractory_counter - 1;
            end

            // Update adaptation
            if (learning_enable) begin
                if (spike_condition) begin
                    adaptation <= adaptation + (adaptation >> ADAPTATION_RATE);
                end else if (adaptation > 0) begin
                    adaptation <= adaptation - 1;
                end
            end

            // Update threshold
            threshold <= THRESHOLD_BASE + adaptation;

            // Update spike output and count
            spike_out <= spike_condition;
            if (spike_condition) begin
                spike_count <= spike_count + 1;
            end
        end
    end

endmodule