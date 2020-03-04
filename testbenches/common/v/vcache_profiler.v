/**
 *    vcache_profiler.v
 *    
 */


module vcache_profiler
  import bsg_cache_pkg::*;
  #(parameter data_width_p="inv"
    , parameter addr_width_p="inv"

    , parameter dma_pkt_width_lp=`bsg_cache_dma_pkt_width(addr_width_p)
    ,parameter bsg_cache_pkt_width_lp=`bsg_cache_pkt_width(addr_width_p,data_width_p) 
  )
  (
    input clk_i
    , input reset_i


    // For request stats incoming to tl stage
    // As it takes one cycle from the time ready_o goes hight,
    // to load the incoming cache packet into tl registers,
    // We directly look at incoming cache_pkt into the cache
    , input v_i
    , input ready_o
    , input [addr_width_p-1:0] addr_tl_r
    , input [data_width_p-1:0] data_tl_r
    , input bsg_cache_decode_s decode_tl_r
    , input [bsg_cache_pkt_width_lp-1:0] cache_pkt_i
    , input bsg_cache_decode_s decode


    // For responses going out of verify stage
    , input v_o
    , input yumi_i
    , input v_v_r
    , input miss_v
    , input [addr_width_p-1:0] addr_v_r
    , input [data_width_p-1:0] data_v_r
    , input bsg_cache_decode_s decode_v_r


    , input [dma_pkt_width_lp-1:0] dma_pkt_o
    , input dma_pkt_v_o
    , input dma_pkt_yumi_i


    , input [31:0] global_ctr_i
    , input print_stat_v_i
    , input [data_width_p-1:0] print_stat_tag_i


    , input trace_en_i // from top-level testbench
  );


  // For decoding the packed cache packet incoming to bsg_cache
  //
  `declare_bsg_cache_pkt_s(addr_width_p,data_width_p);
  bsg_cache_pkt_s cache_pkt;
  assign cache_pkt = cache_pkt_i;


  `declare_bsg_cache_dma_pkt_s(addr_width_p);
  bsg_cache_dma_pkt_s dma_pkt;
  assign dma_pkt = dma_pkt_o;



  // event signals

  // Incoming request
  // miss handler signals
  // when miss is high, miss handler is active and output is not ready
  // miss_ld/st signals refer to the type of missed request
  //
  wire miss    = v_v_r & miss_v & ~(v_o | yumi_i); 
  wire miss_ld = v_v_r & miss_v & ~(v_o | yumi_i) & decode_v_r.ld_op;
  wire miss_st = v_v_r & miss_v & ~(v_o | yumi_i) & decode_v_r.st_op;


  // Outgoing response
  // Load/store output is ready 
  // when inc_ld/st is high it means a hit load/store is ready
  // when inc_ld/st_miss is high it means a missed load/store is ready
  //
  wire inc_ld = v_o & yumi_i & decode_v_r.ld_op;
  wire inc_st = v_o & yumi_i & decode_v_r.st_op;
  wire inc_ld_miss = v_o & yumi_i & decode_v_r.ld_op & miss_v;
  wire inc_st_miss = v_o & yumi_i & decode_v_r.st_op & miss_v;
  wire inc_dma_read_req = dma_pkt_v_o & dma_pkt_yumi_i & ~dma_pkt.write_not_read;
  wire inc_dma_write_req = dma_pkt_v_o & dma_pkt_yumi_i & dma_pkt.write_not_read;



  // stats counting
  //
  typedef struct packed {
    integer ld_count;
    integer st_count;
    integer ld_miss_count;
    integer st_miss_count;
    integer dma_read_req;
    integer dma_write_req;
  } vcache_stat_s;

  vcache_stat_s stat_r;

  always_ff @ (posedge clk_i) begin

    if (reset_i) begin
      stat_r <= '0;
    end
    else begin
      if (inc_ld) stat_r.ld_count++;
      if (inc_st) stat_r.st_count++;
      if (inc_ld_miss) stat_r.ld_miss_count++;
      if (inc_st_miss) stat_r.st_miss_count++;
      if (inc_dma_read_req) stat_r.dma_read_req++;
      if (inc_dma_write_req) stat_r.dma_write_req++;
    end

  end


  // file logging
  //
  localparam logfile_lp = "vcache_stats.log";

  string my_name;
  integer fd_log;

  initial begin

    my_name = $sformatf("%m");
    if (str_match(my_name, "vcache[0]")) begin
      fd_log = $fopen(logfile_lp, "w");
      $fwrite(fd_log, "instance,global_ctr,tag,ld,st,ld_miss,st_miss,dma_read_req,dma_write_req\n");
      $fclose(fd_log);
    end

    forever begin
      @(negedge clk_i) begin
        if (~reset_i & print_stat_v_i) begin

          $display("[BSG_INFO][VCACHE_PROFILER] %s t=%0t printing stats.", my_name, $time);

          fd_log = $fopen(logfile_lp, "a");
          $fwrite(fd_log, "%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
            my_name, global_ctr_i, print_stat_tag_i,
            stat_r.ld_count, stat_r.st_count,
            stat_r.ld_miss_count, stat_r.st_miss_count,
            stat_r.dma_read_req, stat_r.dma_write_req 
          );   
          $fclose(fd_log);
        end
      end
    end
  end


  // string match helper
  //
  function str_match(string s1, s2);

    int len1, len2;
    len1 = s1.len();
    len2 = s2.len();

    if (len2 > len1)
      return 0;

    for (int i = 0; i < len1-len2+1; i++)
      if (s1.substr(i,i+len2-1) == s2)
        return 1;
  
  endfunction

endmodule
