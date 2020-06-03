-- Author: Frank Mori Hess fmh6jj@gmail.com
-- Copyright 2020 Fluke Corporation

-- TODO
-- implement colors_per_pixel_per_plane and support colors_per_beat < colors_per_pixel_per_plane


library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.ceil;
use IEEE.math_real.log2;
use work.fmh_framebuffer_ocram; 

entity fmh_framebuffer is
	generic(
		bits_per_color: positive := 8;
		colors_per_pixel_per_plane: positive := 4;
		colors_per_beat: positive := 4;
		num_color_planes: positive := 1;
		memory_bytes_per_pixel_per_plane: positive := 4;
		memory_address_width: positive := 32;
		memory_burstcount_width: positive := 5;
		memory_data_width: positive := 64;
		max_frame_width: positive := 16#1000#;
		default_horizontal_flip: boolean := false;
		default_vertical_flip: boolean := false
	);
	port(
		clock: in std_logic;
		reset: in std_logic;
		
		-- avalon master for buffer memory
		memory_address: out std_logic_vector(memory_address_width - 1 downto 0);
		memory_burstcount: out std_logic_vector(memory_burstcount_width - 1 downto 0);
		memory_readdata: in std_logic_vector(memory_data_width - 1 downto 0);
		memory_read: out std_logic;
		memory_readdatavalid: in std_logic;
		memory_waitrequest: in std_logic;
		
		-- avalon slave
		slave_address: in std_logic_vector(4 downto 0);
		slave_readdata: out std_logic_vector(31 downto 0);
		slave_read: in std_logic;
		slave_writedata: in std_logic_vector(31 downto 0);
		slave_write: in std_logic;
		slave_irq: out std_logic;
		
		-- avalon st video out
		video_out_ready: in std_logic;
		video_out_valid: out std_logic;
		video_out_data: out std_logic_vector(bits_per_color * colors_per_beat - 1 downto 0);
		video_out_startofpacket: out std_logic;
		video_out_endofpacket: out std_logic
	);
end fmh_framebuffer;

architecture fmh_framebuffer_arch of fmh_framebuffer is

	signal safe_reset: std_logic;
	type packet_send_state_enum is (packet_send_state_idle, packet_send_state_command, packet_send_state_video);
	signal packet_send_state: packet_send_state_enum;
	-- avalon max burstcount is biggest power of 2 that can fit into burstcount_width (so 16 for a 5 bit wide burstcount)
	constant max_burstcount: positive := to_integer(shift_left(to_unsigned(1, memory_burstcount_width), memory_burstcount_width - 1));
	constant memory_data_width_in_bytes: positive := memory_data_width / 8;
	signal frame_width: unsigned(15 downto 0);
	signal frame_height: unsigned(15 downto 0);
	signal requested_frame_width: unsigned(frame_width'range);
	signal requested_frame_height: unsigned(frame_height'range);
	signal beat_index: unsigned(31 downto 0);
	signal symbol_index_base: unsigned(31 downto 0);
	constant interlacing: std_logic_vector(3 downto 0) := "0010"; -- progressive
	signal buffer_base_address: unsigned(memory_address_width - 1 downto 0);
	
	-- buffer row cache stuff
	constant log2_num_cache_rows : positive := 1;
	constant num_cache_rows : positive := 2 ** log2_num_cache_rows;
	signal request_prefetch: std_logic_vector(num_cache_rows - 1 downto 0);
	signal prefetch_complete: std_logic_vector(num_cache_rows - 1 downto 0);
	constant cache_address_width: natural := integer(ceil(log2(real(max_frame_width * memory_bytes_per_pixel_per_plane / memory_data_width_in_bytes + 1)))) + 
		log2_num_cache_rows;
	type prefetch_address_type is array (num_cache_rows - 1 downto 0) of unsigned(cache_address_width - 1 downto 0);
	signal prefetch_address: prefetch_address_type;
	signal cache_write_address: unsigned(cache_address_width - 1 downto 0);
	signal cache_write_enable: std_logic;
	signal cache_write_data: std_logic_vector(memory_data_width - 1 downto 0);
	signal cache_read_address: unsigned(cache_address_width - 1 downto 0);
	signal cache_read_data: std_logic_vector(memory_data_width - 1 downto 0);
	
	type memory_burst_read_state_enum is (memory_burst_read_state_idle, memory_burst_read_state_initiate, memory_burst_read_state_collect);
	signal memory_burst_read_state: memory_burst_read_state_enum;
	
	signal ready_to_send_frame: boolean;
	signal go: std_logic;
	
	-- irq
	signal slave_irq_enable: std_logic;
	signal raw_slave_irq: std_logic;
	signal clear_slave_irq: std_logic; -- pulsed
begin
	
	assert num_color_planes = 1 report "Only num_color_planes=1 is currently supported.";
	
	my_ocram : entity work.fmh_framebuffer_ocram
		generic map (
			address_width => cache_address_width,
			data_width => memory_data_width
		)
		port map (
			clock => clock,
			write_enable => cache_write_enable,
			write_address => cache_write_address,
			write_data => cache_write_data,
			read_address => cache_read_address,
			read_data => cache_read_data
		);

	-- sync release of reset
	process (reset, clock)
	begin
		if to_X01(reset) = '1' then
			safe_reset <= '1';
		elsif rising_edge(clock) then
			safe_reset <= '0';
		end if;
	end process;
 
	ready_to_send_frame <= go = '1' and 
		to_X01(video_out_ready) = '1' and
		buffer_base_address /= 0 and
		requested_frame_width /= 0 and
		requested_frame_height /= 0 and
		unsigned(request_prefetch) = 0 and
		unsigned(prefetch_complete) = 0;
	
	-- generate videout out stream
	process(safe_reset, clock)	
		constant first_width_symbol_index: positive := colors_per_beat;
		constant first_height_symbol_index: positive := colors_per_beat + 4;
		constant interlacing_symbol_index: positive := colors_per_beat + 8;
		variable symbol_index: unsigned(31 downto 0);
		variable current_column: unsigned(frame_width'range);
		variable current_row: unsigned(frame_height'range);
		variable next_row: unsigned(frame_height'range);
		variable row_increment: integer range -1 to 1 := 1;

		function calculate_cache_address(row: unsigned; column: unsigned; width: unsigned) 
			return unsigned is
			variable result: unsigned(cache_address_width - 1 downto 0);
		begin
			result := resize((row * width + column) * memory_bytes_per_pixel_per_plane / memory_data_width_in_bytes, cache_address_width);
			return result;
		end function calculate_cache_address;
		
		function calculate_cache_data_offset(row: unsigned; column: unsigned; width: unsigned)
			return natural is
		begin
			return to_integer((row * width + column) * memory_bytes_per_pixel_per_plane mod memory_data_width_in_bytes);
		end function calculate_cache_data_offset;
		
	begin
		if to_X01(safe_reset) = '1' then
			packet_send_state <= packet_send_state_idle;
			video_out_valid <= '0';
			video_out_data <= (others => '0');
			video_out_startofpacket <= '0';
			video_out_endofpacket <= '0';
			beat_index <= (others => '0');
			symbol_index_base <= (others => '0');
			frame_width <= (others => '0');
			frame_height <= (others => '0');
			symbol_index := (others => '0');
			current_column := (others => '0');
			current_row := (others => '0');
			next_row := (others => '0');
			request_prefetch <= (others => '0');
			prefetch_address <= (others => (others => '0'));
			row_increment := 1;
			raw_slave_irq <= '0';
			cache_read_address <= (others => '0');
		elsif rising_edge(clock) then

			if packet_send_state = packet_send_state_idle then
				video_out_valid <= '0';
				video_out_data <= (others => '0');
				video_out_startofpacket <= '0';
				video_out_endofpacket <= '0';
				beat_index <= (others => '0');
				symbol_index_base <= (others => '0');
				current_column := (others => '0');
				current_row := (others => '0');
				row_increment := 1;
				next_row := current_row + row_increment;
				frame_width <= requested_frame_width;
				frame_height <= requested_frame_height;
				if ready_to_send_frame then
					prefetch_address(to_integer(current_row(log2_num_cache_rows - 1 downto 0))) <= 
						calculate_cache_address(current_row, to_unsigned(0, current_column'length), frame_width);
					cache_read_address <= calculate_cache_address(current_row, current_column, frame_width);
					request_prefetch(to_integer(current_row(log2_num_cache_rows - 1 downto 0))) <= '1';
					packet_send_state <= packet_send_state_command;
				end if;
			else
				if packet_send_state = packet_send_state_command then
					if to_X01(video_out_ready) = '1' then
						beat_index <= beat_index + 1;
						symbol_index_base <= symbol_index_base + colors_per_beat;
						video_out_valid <= '1';

						if to_integer(beat_index) = 0 then
							video_out_data <= (others => '1'); -- least significant nibble must be all 1's for control packet, the rest are don't care
							video_out_startofpacket <= '1';
							video_out_endofpacket <= '0';
						else
							video_out_data <= (others => '0');
							video_out_startofpacket <= '0';
							video_out_endofpacket <= '0';
							for i in 0 to colors_per_beat - 1 loop
								symbol_index := symbol_index_base + i;

								if symbol_index >= first_width_symbol_index and
									symbol_index < first_height_symbol_index then
									video_out_data(i * bits_per_color + 3 downto i * bits_per_color) <= 
										std_logic_vector(frame_width(15 - (to_integer(symbol_index) - first_width_symbol_index) * 4 
											downto 12 - (to_integer(symbol_index) - first_width_symbol_index) * 4));
								elsif symbol_index >= first_height_symbol_index and
									symbol_index < interlacing_symbol_index then
									video_out_data(i * bits_per_color + 3 downto i * bits_per_color) <= 
										std_logic_vector(frame_height(15 - (to_integer(symbol_index) - first_height_symbol_index) * 4 
											downto 12 - (to_integer(symbol_index) - first_height_symbol_index) * 4));
								elsif symbol_index = interlacing_symbol_index then
									video_out_data(i * bits_per_color + 3 downto i * bits_per_color) <= interlacing;
									video_out_endofpacket <= '1';
									beat_index <= (others => '0');
									symbol_index_base <= (others => '0');
									packet_send_state <= packet_send_state_video;
								end if;
							end loop;
						end if;
					else
						video_out_valid <= '0';
					end if;

				elsif packet_send_state = packet_send_state_video then
					if to_X01(video_out_ready) = '1' and
						request_prefetch(to_integer(current_row(log2_num_cache_rows - 1 downto 0))) = '0' and
						prefetch_complete(to_integer(current_row(log2_num_cache_rows - 1 downto 0))) = '0'
					then
						beat_index <= beat_index + 1;
						symbol_index_base <= symbol_index_base + colors_per_beat;
						video_out_valid <= '1'; -- FIXME: take into account availablity of framebuffer data

						if to_integer(beat_index) = 0 then
							video_out_data <= (others => '0'); -- least significant nibble must be all 0's for video packet, the rest are don't care
							video_out_startofpacket <= '1';
							video_out_endofpacket <= '0';
						else
							video_out_data <= (others => '0');
							video_out_startofpacket <= '0';
							video_out_endofpacket <= '0';
							
							for i in 0 to (colors_per_pixel_per_plane * bits_per_color) - 1 loop
								video_out_data(i) <= 
									cache_read_data(calculate_cache_data_offset(current_row, current_column, frame_width) * 8 + i);
							end loop;
							
							-- prefetch next row
							next_row := current_row + row_increment;
							if to_integer(current_column) = 0 then -- FIXME: will break when we support horizontal flip
								prefetch_address(to_integer(next_row(log2_num_cache_rows - 1 downto 0))) <= 
									calculate_cache_address(next_row, to_unsigned(0, current_column'length), frame_width);
								request_prefetch(to_integer(next_row(log2_num_cache_rows - 1 downto 0))) <= '1';
							end if;
							-- increment column/row
							current_column := current_column + 1;
							if current_column >= frame_width then
								current_column := (others => '0');
								current_row := next_row;
								if current_row >= frame_height then
									current_row := (others => '0');
									video_out_endofpacket <= '1';
									raw_slave_irq <= '1';
									packet_send_state <= packet_send_state_idle;
								end if;
							end if;
							cache_read_address <= calculate_cache_address(current_row, current_column, frame_width);
						end if;
						
					else
						video_out_valid <= '0';
					end if;
				end if;
				
				-- clear request_prefetch
				for i in 0 to num_cache_rows - 1 loop
					if request_prefetch(i) = '1' and prefetch_complete(i) = '1' then
						request_prefetch(i) <= '0';
					end if;
				end loop;
			end if;
			-- clear irq
			if clear_slave_irq = '1' then
				raw_slave_irq <= '0';
			end if;
		end if;
	end process;
	
	-- read buffer memory
	process(safe_reset, clock)
		variable num_reads_remaining_in_burst: unsigned(memory_burstcount_width - 1 downto 0);
		variable num_bytes_read: integer range 0 to 
			max_frame_width * memory_bytes_per_pixel_per_plane; 
		variable current_prefetch_index: integer range -1 to num_cache_rows - 1;
	begin
		if to_X01(safe_reset) = '1' then
			memory_address <= (others => '0');
			memory_burstcount <= (others => '0');
			memory_read <= '0';
			prefetch_complete <= (others => '0');
			memory_burst_read_state <= memory_burst_read_state_idle;
			num_reads_remaining_in_burst := (others => '0');
			num_bytes_read := 0;
			current_prefetch_index := -1;
			cache_write_address <= (others => '0');
			cache_write_enable <= '0';
			cache_write_data <= (others => '0');
		elsif rising_edge(clock) then
			for i in 0 to num_cache_rows - 1 loop
				if request_prefetch(i) = '1' and prefetch_complete(i) = '0' and current_prefetch_index < 0 then
					current_prefetch_index := i;
				end if;
				
				-- clear prefetch_complete as needed
				if prefetch_complete(i) = '1' and request_prefetch(i) = '0' then
					prefetch_complete(i) <= '0';
				end if;
			end loop;
			
			cache_write_address <= (others => '0');
			cache_write_enable <= '0';
			cache_write_data <= (others => '0');

			if current_prefetch_index >= 0 then
				if memory_burst_read_state = memory_burst_read_state_idle then
					num_bytes_read := 0;
					memory_burst_read_state <= memory_burst_read_state_initiate;

				elsif memory_burst_read_state = memory_burst_read_state_initiate then

					if buffer_base_address /= 0 then
						-- FIXME: be more careful to align reads and avoid reading beyond end of buffer
						memory_address <= std_logic_vector(buffer_base_address + prefetch_address(current_prefetch_index) * memory_data_width_in_bytes + num_bytes_read);
						num_reads_remaining_in_burst := to_unsigned(max_burstcount, num_reads_remaining_in_burst'LENGTH);
						memory_burstcount <= std_logic_vector(num_reads_remaining_in_burst);
						memory_read <= '1';
						memory_burst_read_state <= memory_burst_read_state_collect;
					end if;
					
				elsif memory_burst_read_state = memory_burst_read_state_collect then
					if to_X01(memory_readdatavalid) = '1' then
						cache_write_address <= prefetch_address(current_prefetch_index) + num_bytes_read / memory_data_width_in_bytes;
						cache_write_enable <= '1';
						cache_write_data <= memory_readdata;
						num_bytes_read := num_bytes_read + memory_data_width_in_bytes;
						num_reads_remaining_in_burst := num_reads_remaining_in_burst - 1;
						if to_integer(num_reads_remaining_in_burst) = 0 then
							memory_read <= '0';
							if num_bytes_read < frame_width * memory_bytes_per_pixel_per_plane then --FIXME we need to take alignment into account, this may stop early
								memory_burst_read_state <= memory_burst_read_state_initiate;
							else
								prefetch_complete(current_prefetch_index) <= '1';
								current_prefetch_index := -1;
								memory_burst_read_state <= memory_burst_read_state_idle;
							end if;
						end if;
					end if;
				end if;
			end if;
			
		end if;
	end process;

	-- slave io port reads
	process(safe_reset, clock)
	begin
		if to_X01(safe_reset) = '1' then
			slave_readdata <= (others => '0');
		elsif rising_edge(clock) then
			slave_readdata <= (others => '0');
		end if;
	end process;
	
	-- slave io port writes
	process(safe_reset, clock)
		variable prev_slave_write: std_logic;
		variable temp_frame_width: unsigned(requested_frame_width'length - 1 downto 0);
	begin
		if to_X01(safe_reset) = '1' then
			buffer_base_address <= (others => '0');
			prev_slave_write := '0';
			requested_frame_width <= (others => '0');
			requested_frame_height <= (others => '0');
			go <= '0';
			slave_irq_enable <= '0';
			clear_slave_irq <= '0';
		elsif rising_edge(clock) then
			clear_slave_irq <= '0';
			
			if prev_slave_write = '0' and to_X01(slave_write) = '1' then
				case to_integer(unsigned(slave_address)) is
				when 16#0# =>
					go <= to_X01(slave_writedata(0));
					slave_irq_enable <= to_X01(slave_writedata(1));
				when 16#2# =>
					if to_X01(slave_writedata(0)) = '1' then
						clear_slave_irq <= '1';
					end if;
				when 16#4# =>
					buffer_base_address <= unsigned(to_X01(slave_writedata));
				when 16#8# =>
					temp_frame_width := unsigned(to_X01(slave_writedata(requested_frame_width'length - 1 downto 0)));
					if temp_frame_width < max_frame_width then
						requested_frame_width <= temp_frame_width;
					end if;
				when 16#9# =>
					requested_frame_height <= unsigned(to_X01(slave_writedata(requested_frame_height'length - 1 downto 0)));
				when others =>
				end case;
			end if;
			
			prev_slave_write := to_X01(slave_write);
		end if;
	end process;

	slave_irq <= raw_slave_irq and slave_irq_enable;
end fmh_framebuffer_arch;
