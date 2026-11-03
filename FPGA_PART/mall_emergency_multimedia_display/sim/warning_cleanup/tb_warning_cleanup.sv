`timescale 1ns / 1ps
module tb_warning_cleanup;
    reg clk = 0;
    always #5 clk = !clk;
    reg rst_n = 0, vsync = 0, de = 0;
    reg [9:0] x = 0, y = 0;
    reg [23:0] rgb = 0;
    reg enable = 1, active = 1, alarm = 0, pcm_valid = 0;
    reg [2:0] kind = 0;
    reg signed [15:0] pcm = 0;
    reg [10:0] address = 0;
    wire [23:0] emergency_new, emergency_old, marquee_new, marquee_old;
    wire [23:0] wave_new, wave_old, brand_new, brand_old;
    wire hit_new, hit_old, brand_hit_new, brand_hit_old;
    wire hs_new, hs_old, vs_new, vs_old, de_new, de_old;
    wire [9:0] px_new, px_old;
    emergency_font_rom u_e_new(clk,address,emergency_new);
    emergency_font_rom_reference u_e_old(clk,address,emergency_old);
    mall_marquee_font_rom u_m_new(clk,address[9:0],marquee_new);
    mall_marquee_font_rom_reference u_m_old(clk,address[9:0],marquee_old);
    audio_envelope_visualizer #(.SUPPORT_FIRE(1),.SUPPORT_MULTI_EMERGENCY(1),
        .WAVE_X(32),.WAVE_Y(420),.WAVE_WIDTH(576),.BIN_SAMPLES(8)) u_wave_new(
        .clk(clk),.rst_n(rst_n),.vsync(vsync),.de(de),.rgb_in(rgb),.pixel_x(x),
        .enable(enable),.audio_active(active),.fire_active(alarm),.emergency_kind(kind),
        .pcm_tap_valid(pcm_valid),.pcm_tap_left(pcm),.rgb_out(wave_new),.waveform_active(hit_new));
    audio_envelope_visualizer_reference #(.SUPPORT_FIRE(1),.SUPPORT_MULTI_EMERGENCY(1),
        .WAVE_X(32),.WAVE_Y(420),.WAVE_WIDTH(576),.BIN_SAMPLES(8)) u_wave_old(
        .clk(clk),.rst_n(rst_n),.vsync(vsync),.de(de),.rgb_in(rgb),.pixel_x(x),
        .enable(enable),.audio_active(active),.fire_active(alarm),.emergency_kind(kind),
        .pcm_tap_valid(pcm_valid),.pcm_tap_left(pcm),.rgb_out(wave_old),.waveform_active(hit_old));
    brand_watermark_24 #(.ENABLE(1)) u_b_new(
        .clk(clk),.rst_n(rst_n),.hsync(1'b1),.vsync(vsync),.de(de),.rgb_in(rgb),
        .pixel_x(x),.pixel_y({2'b00,y}),.overlay_active_in(1'b0),.hsync_out(hs_new),
        .vsync_out(vs_new),.de_out(de_new),.pixel_x_out(px_new),.rgb_out(brand_new),
        .overlay_active_out(brand_hit_new));
    brand_watermark_24_reference #(.ENABLE(1)) u_b_old(
        .clk(clk),.rst_n(rst_n),.hsync(1'b1),.vsync(vsync),.de(de),.rgb_in(rgb),
        .pixel_x(x),.pixel_y({2'b00,y}),.overlay_active_in(1'b0),.hsync_out(hs_old),
        .vsync_out(vs_old),.de_out(de_old),.pixel_x_out(px_old),.rgb_out(brand_old),
        .overlay_active_out(brand_hit_old));
    integer h, v, f, cycles = 0, pixels = 0;
    always @(posedge clk) begin
        #1;
        if (emergency_new !== emergency_old || marquee_new !== marquee_old)
            $fatal(1,"Font content or latency mismatch address=%d",address);
        if (rst_n) begin
            if ({wave_new,hit_new} !== {wave_old,hit_old})
                $fatal(1,"Waveform mismatch frame=%d x=%d y=%d",f,x,y);
            if ({brand_new,brand_hit_new,hs_new,vs_new,de_new,px_new} !==
                {brand_old,brand_hit_old,hs_old,vs_old,de_old,px_old})
                $fatal(1,"Legacy compatibility stage mismatch");
            cycles = cycles+1;
            if (de) pixels = pixels+1;
        end
    end
    initial begin
        repeat(5) @(negedge clk);
        rst_n = 1;
        for (f=0;f<10;f=f+1) begin
            enable = f!=8;
            active = f!=2;
            alarm = f>=4 && f<=7;
            kind = f==4 ? 1 : f==5 ? 3 : f==6 ? 4 : f==7 ? 2 : 0;
            for(v=0;v<525;v=v+1) begin
                for(h=0;h<800;h=h+1) begin
                    @(negedge clk);
                    vsync = v>=2;
                    de = v>=35 && v<515 && h>=144 && h<784;
                    x = h>=144 ? h-144 : 0;
                    y = v>=35 ? v-35 : 0;
                    pcm_valid = h%7==0;
                    pcm = (h*391+v*733+f*1701) & 16'hffff;
                    rgb = {h[7:0],v[7:0],f[7:0]};
                    address = address+1'b1;
                end
            end
            $display("Compared frame %0d",f);
        end
        @(negedge clk);
        $display("TEST PASSED: native wrapper contract vs baseline, cycles=%0d pixels=%0d",cycles,pixels);
        $finish;
    end
endmodule
