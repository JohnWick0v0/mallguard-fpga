create_clock -name sys_clk -period 20.000 -waveform {0.000 10.000} [get_ports {sys_clk}]
create_generated_clock -name pixel_clk_5x -source [get_ports {sys_clk}] -master_clock sys_clk -multiply_by 2.5 [get_nets {pixel_clk_5x}]
create_generated_clock -name pixel_clk -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 2 [get_nets {pixel_clk}]
create_generated_clock -name mem_clk -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 1.25 -phase 0 [get_pins {u_mem_pll/pll_inst.clkc[1]}]
create_generated_clock -name mem_clk_shift -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 1.25 -phase 172.8 [get_pins {u_mem_pll/pll_inst.clkc[2]}]

set_false_path -to [get_regs -hier {*/s1}]
set_false_path -to [get_regs -hier {*/request_sync1_mem}]
set_false_path -to [get_regs -hier {*/index_sync1_mem[*]}]
set_false_path -to [get_regs -hier {*/ack_sync1}]
set_false_path -to [get_regs -hier {*req_sync1*}]
set_false_path -to [get_regs -hier {*/index_sync1[*]}]
set_false_path -to [get_regs -hier {*busy_sync1*}]
set_false_path -to [get_regs -hier {*commit_sync1*}]

# The inherited FIFO uses Gray pointers. Limit each crossing to one source
# clock period instead of declaring the complete pixel/memory domains false.
set_max_delay -from [get_regs -hier {u_video/u_reader/u_read_fifo/wr_to_rd_cross_inst/primary_addr_gray_reg[*]}] -to [get_regs -hier {u_video/u_reader/u_read_fifo/wr_to_rd_cross_inst/sync_r1[*]}] 25.000 -datapath_only
set_max_delay -from [get_regs -hier {u_video/u_reader/u_read_fifo/rd_to_wr_cross_inst/primary_addr_gray_reg[*]}] -to [get_regs -hier {u_video/u_reader/u_read_fifo/rd_to_wr_cross_inst/sync_r1[*]}] 40.000 -datapath_only

# Bound each implemented ODDR-to-pad path. This is a digital per-lane delay
# limit, not a claim about complete rise/fall pairwise skew or the analog eye.
set_max_delay -from [get_clocks {pixel_clk_5x}] \
    -to [get_ports {HDMI_CLK_P HDMI_D0_P HDMI_D1_P HDMI_D2_P}] \
    8.000 -datapath_only

set_false_path -to [get_regs -hier {u_wav/ok1}]
set_max_delay -from [get_regs -hier {u_wav/u_fifo/wg[*]}] -to [get_regs -hier {u_wav/u_fifo/wg1[*]}] 25.000 -datapath_only
set_max_delay -from [get_regs -hier {u_wav/u_fifo/rg[*]}] -to [get_regs -hier {u_wav/u_fifo/rg1[*]}] 40.000 -datapath_only

# Mechanical keys are asynchronous inputs. TD packs the first synchronizer
# stage into the pad IREG, so get_regs cannot select it after mapping.
# These port-started paths stop at that first stage; the second stage and
# every subsequent synchronous path remain timed.
set_false_path -from [get_ports {key1_n key2_n key3_n key4_n}]
# Official serializer first phase synchronizer.
set_false_path -to [get_regs -hier {*S_odd_even_1d*}]

# Asynchronous UART input, and first stages of alarm-state CDC.
set_false_path -from [get_ports {uart_rx_i}]
set_false_path -to [get_regs -hier {*/freeze_s1}]

# SW1 is asynchronous; only the input synchronizer's first stage is exempt.
set_false_path -from [get_ports {sw1_n}]
set_false_path -to [get_regs -hier {u_alarm_wav/ok1}]
set_max_delay -from [get_regs -hier {u_alarm_wav/u_fifo/wg[*]}] -to [get_regs -hier {u_alarm_wav/u_fifo/wg1[*]}] 25.000 -datapath_only
set_max_delay -from [get_regs -hier {u_alarm_wav/u_fifo/rg[*]}] -to [get_regs -hier {u_alarm_wav/u_fifo/rg1[*]}] 40.000 -datapath_only

set_false_path -from [get_ports {sw2_n sw3_n}]

# The slot bus changes only at a supervisor request. The ingest frontend is
# reset while copying the old frame, and held reset for two additional video
# frame boundaries before its start pulse. It cannot consume the new slot
# before that qualification window. Bound this stable bus to 100ns; all
# same-clock supervisor and normal video paths remain fully timed.
set_max_delay -from [get_regs -hier {u_timeslot/selected_slot*}] -to [get_clocks {mem_clk}] 100.000 -datapath_only
set_input_delay -clock [get_clocks {mem_clk}] -max 25.500 [get_ports {sd_miso}]
set_input_delay -clock [get_clocks {mem_clk}] -min 2.000 [get_ports {sd_miso}]
set_multicycle_path 2 -setup -from [get_ports {sd_miso}]
set_multicycle_path 1 -hold -from [get_ports {sd_miso}]
set_max_delay -from [get_clocks {mem_clk}] -to [get_ports {sd_sclk sd_mosi}] 9.500 -datapath_only
set_max_delay -from [get_clocks {mem_clk}] -to [get_ports {sd_cs_n}] 12.000 -datapath_only

set_false_path -from [get_ports {sw4_n}]

# Video bank handoff: source holds bank/index until the synchronized ACK.
# Only the first synchronizer stage is asynchronous; its second stage remains timed.
set_false_path -to [get_regs -hier {u_clip/ack1}]
set_false_path -to [get_regs -hier {u_clip/u_av_clock/rt1}]
set_false_path -to [get_regs -hier {u_clip/u_av_clock/rb1}]
set_false_path -to [get_regs -hier {u_clip/u_av_clock/ri1*}]
set_false_path -to [get_regs -hier {clip_sys1*}]
set_max_delay -from [get_regs -hier {u_clip/u_pcm_fifo/u_ram/wg[*]}] -to [get_regs -hier {u_clip/u_pcm_fifo/u_ram/wg1[*]}] 25.000 -datapath_only
set_max_delay -from [get_regs -hier {u_clip/u_pcm_fifo/u_ram/rg[*]}] -to [get_regs -hier {u_clip/u_pcm_fifo/u_ram/rg1[*]}] 40.000 -datapath_only

# JOURNAL_CAPTURE_WINDOW
# Only this CRC-result path has a two-cycle capture window. In the real
# config_flash_journal controller, slot1_data is latched at edge 0;
# ST_LOAD_PULSE raises journal_load_start at edge 1; the child observes it
# at edge 2 and consumes slot1_good at edge 3. Thus its edge-2 CRC capture
# is the first observed value. The source is held throughout this window.
# tb_journal_window verifies 40 loads/save-reloads while deliberately making
# the first CRC capture wrong. Keep minimum-delay checking with hold=1.
# Select the exact result name: slot1_good* also matches source-bit aliases.
set_multicycle_path 2 -setup -from [get_regs -hier {u_player_config/u_journal/slot1_raw[*]}] -to [get_regs -hier {u_player_config/u_journal/u_journal/slot1_good}]
set_multicycle_path 1 -hold -from [get_regs -hier {u_player_config/u_journal/slot1_raw[*]}] -to [get_regs -hier {u_player_config/u_journal/u_journal/slot1_good}]

# SLOT0_CRC_CAPTURE_WINDOW
# Slot0 is captured in ST_READ0_WAIT. The controller then issues and completes
# the entire slot1 Flash read before ST_LOAD_PULSE -> ST_LOAD_WAIT consumes
# either CRC result. Save requests are accepted only in ST_IDLE, after the
# previous load has finished. Thus slot0_good is never consumed at the first
# edge after slot0_data changes. This exact source/result pair has at least
# the same two-cycle window as slot1 above; hold=1 keeps same-edge checking.
# tb_flash_crc_windows forces BOTH first CRC captures wrong and checks that
# load/save consumption occurs only after the guaranteed two-cycle window.
set_multicycle_path 2 -setup -from [get_regs -hier {u_player_config/u_journal/slot0_raw[*]}] -to [get_regs -hier {u_player_config/u_journal/u_journal/slot0_good}]
set_multicycle_path 1 -hold -from [get_regs -hier {u_player_config/u_journal/slot0_raw[*]}] -to [get_regs -hier {u_player_config/u_journal/u_journal/slot0_good}]

# New boot-progress mailboxes only. Destination capture occurs after request
# meta -> sync -> comparison (at least two complete destination periods).
# Bound each held data bit to ONE destination period. Source cannot overwrite
# it until acknowledgement has crossed two source FFs, so same-edge hold is
# not the enabled sampling relationship. All second synchronizer stages and
# original video/storage/key paths keep their existing timing checks.
set_false_path -to [get_regs -hier -regexp {^u_boot_status_(sys|pix)/(req_meta|ack_meta)$}]
set_max_delay -from [get_regs -hier -regexp {^u_boot_status_sys/held\[[0-9]+\]$}] -to [get_regs -hier -regexp {^u_boot_status_sys/dst_value\[[0-9]+\]$}] 20.000 -datapath_only
set_false_path -hold -from [get_regs -hier -regexp {^u_boot_status_sys/held\[[0-9]+\]$}] -to [get_regs -hier -regexp {^u_boot_status_sys/dst_value\[[0-9]+\]$}]
set_max_delay -from [get_regs -hier -regexp {^u_boot_status_pix/held\[[0-9]+\]$}] -to [get_regs -hier -regexp {^u_boot_status_pix/dst_value\[[0-9]+\]$}] 40.000 -datapath_only
set_false_path -hold -from [get_regs -hier -regexp {^u_boot_status_pix/held\[[0-9]+\]$}] -to [get_regs -hier -regexp {^u_boot_status_pix/dst_value\[[0-9]+\]$}]
