package tb_pkg; 

`ifndef SIMULATION
 `define SIMULATION
`endif

// Global parameters
localparam NB_OF_BLOCKS = 1000; 
localparam BLOCK_WIDTH = 640; 
localparam DECODE_WIDTH = 256; 
localparam AXI_DATA_WIDTH = 32; 
parameter IN_FIFO_REG_SPACE = DECODE_WIDTH/AXI_DATA_WIDTH; 
parameter OUT_FIFO_REG_SPACE = DECODE_WIDTH/AXI_DATA_WIDTH; 


// Blake parameters
localparam BLAKE_FIFO_DEPTH = 256; 
localparam BLAKE_FIFO_LEVEL_WIDTH = $clog2(BLAKE_FIFO_DEPTH); 

// Keccak parameters
localparam KECCAK_FIFO_DEPTH = 256; 
localparam KECCAK_FIFO_LEVEL_WIDTH = $clog2(KECCAK_FIFO_DEPTH); 

// Cubehash parameters
localparam CUBEHASH0_FIFO_DEPTH = 256; 
localparam CUBEHASH0_FIFO_LEVEL_WIDTH = $clog2(CUBEHASH0_FIFO_DEPTH); 
localparam CUBEHASH1_FIFO_DEPTH = 256; 
localparam CUBEHASH1_FIFO_LEVEL_WIDTH = $clog2(CUBEHASH1_FIFO_DEPTH); 

// Lyra2 parameters
localparam LYRA2_FIFO_DEPTH = 256; 
localparam LYRA2_FIFO_LEVEL_WIDTH = $clog2(LYRA2_FIFO_DEPTH); 

// Skein parameters
localparam SKEIN_FIFO_DEPTH = 256; 
localparam SKEIN_FIFO_LEVEL_WIDTH = $clog2(SKEIN_FIFO_DEPTH);

// BMW parameters
localparam BMW_FIFO_DEPTH = 256; 
localparam BMW_FIFO_LEVEL_WIDTH = $clog2(BMW_FIFO_DEPTH);

// File I/O
typedef struct {
    string input_block; 
    string blake; 
    string keccak; 
    string cubehash0; 
    string lyra2; 
    string skein; 
    string cubehash1; 
    string bmw; 
} t_vectors_path; 

t_vectors_path vectors_path = '{
    "../../hdl/blake/sim/vectors/blake_in.txt",
    "../../hdl/blake/sim/vectors/blake_ref_out.txt",
    "../../hdl/keccak/sim/vectors/keccak_ref_out.txt",
    "../../hdl/cubehash/sim/vectors/cube1_ref_out.txt",
    "../../hdl/lyra2/sim/vectors/lyra2_ref_out.txt",
    "../../hdl/skein/sim/vectors/skein_ref_out.txt",
    "../../hdl/cubehash/sim/vectors/cube2_ref_out.txt",
    "../../hdl/bmw/sim/vectors/bmw_ref_out.txt"
};  

// Unpacked array of NB_BLOCKS * (dynamic) size of DATA_BLOCK
typedef struct {
    bit input_block  [NB_OF_BLOCKS][]; 
    bit blake        [NB_OF_BLOCKS][]; 
    bit keccak       [NB_OF_BLOCKS][]; 
    bit cubehash0    [NB_OF_BLOCKS][]; 
    bit lyra2        [NB_OF_BLOCKS][]; 
    bit skein        [NB_OF_BLOCKS][]; 
    bit cubehash1    [NB_OF_BLOCKS][]; 
    bit bmw          [NB_OF_BLOCKS][]; 
    bit output_block [NB_OF_BLOCKS][]; 
} t_expected_data; 

// Read a vector file and fill the corresponding structure
task automatic read_vectors ( ref bit exp_data [NB_OF_BLOCKS][], input integer size, input string vector_path ); 
    int fd, status; 
    integer block_idx = 0; 
    bit [DECODE_WIDTH-1:0] data_decode; 
    bit [BLOCK_WIDTH-1:0] data_input; 
    bit [2**10-1:0] data; 
    string strvar; 

    // Reading block input  
    fd = $fopen(vector_path, "r"); 
    while ( $fscanf(fd, "%h", data) == 1 ) begin 
        exp_data[block_idx] = new [size];
        if (size == DECODE_WIDTH) begin
            $display("INFO :: Read block data #%0d : 0x%h", block_idx, data[DECODE_WIDTH-1:0]); 
        end else begin
            $display("INFO :: Read block data #%0d : 0x%h", block_idx, data[BLOCK_WIDTH-1:0]);
        end  
        // Assign packed to unpacked array using streaming operator
        {>>{exp_data[block_idx]}} = (size == DECODE_WIDTH) ? {<<{data[DECODE_WIDTH-1:0]}} : {<<{data[BLOCK_WIDTH-1:0]}}; 
        block_idx++;
    end  
    $fclose(fd); 
endtask

// Monitor expected hashing outputs
task automatic check_expected_hash; 
    input string hash_name;  
    ref logic [DECODE_WIDTH-1:0] data; 
    ref logic data_vld; 
    ref bit exp_data [NB_OF_BLOCKS][]; 
    ref logic clk;

    logic [DECODE_WIDTH-1:0] expected;

    foreach ( exp_data[block_idx] ) begin
        wait ( data_vld == 1'b1 && clk == 1'b0); 
        assert ( data == logic'({<<{exp_data[block_idx]}}) ) begin
            $display("[INFO :: %s - %0tps] Transaction # %0d complete.\nDecoded 0x%h.", hash_name, $time, block_idx+1, data); 
        end else begin
            expected = {<<{exp_data[block_idx]}}; 
            $error("[ERROR :: %s - %0tps] Transaction # %0d NOT completed.\nDecoded  0x%h ;\nExpected 0x%h !", hash_name, $time, block_idx+1, data, expected); 
        end
        @ ( posedge clk );  
    end
     
endtask;

// Monitor average hashrate using running-mean
task automatic get_average_hashrate; 
    ref logic clk; 
    ref logic dout_wr_en; 
    input integer sampling_period; 

    integer hash_idx=0; 
    real start_time, stop_time;
    real run_avg, all_avg=0, abs_avg;

    forever begin
        //@ ( posedge(clk) ) begin
        @ ( posedge(dout_wr_en) ) begin
            // Wait for write to output buffer
            //if ( dout_wr_en == 1'b1 ) begin 
                // Set start time
                if ( (hash_idx % sampling_period) == 0 ) begin
                    if ( hash_idx == 0 ) begin
                        start_time = $realtime; 
                    end else begin
                        start_time = stop_time; 
                    end 
                end 
                // Set stop time and compute hashrate
                if ( hash_idx % sampling_period == sampling_period - 1 ) begin
                    stop_time = $realtime; 
                    run_avg = real'($itor(sampling_period)/((stop_time-start_time)/1000000.0));
                    all_avg += run_avg; 
                    abs_avg = all_avg/$itor((hash_idx+1)/sampling_period); 
                    $display("*******************************************************");
                    $display("INFO :: Running average hashrate : %4.4f MH/s", run_avg);
                    $display("INFO :: Continuous average hashrate : %4.4f MH/s", abs_avg);
                    $display("*******************************************************");
                end    
                // Next hash
                hash_idx++; 
            //end 
        end 
    end 
endtask;

endpackage
