-- Author: Frank Mori Hess fmh6jj@gmail.com
-- Copyright 2020 Fluke Corporation

-- TODO
-- support colors_per_beat < colors_per_pixel_per_plane


library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fmh_framebuffer_ocram; 

entity fmh_framebuffer is
	generic(
		bits_per_color: positive := 8;
		colors_per_pixel: positive := 4;
		colors_per_beat: positive := 4; -- number of colors sent per beat of the Avalong ST Video output
		memory_bytes_per_pixel: positive := 4;
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
	function floor_log2(arg: unsigned) return natural is
		variable floor_log2: natural;
	begin
		assert arg /= 0;
		
		for i in arg'length - 1 downto 0 loop
			if to_X01(arg(arg'low + i)) /= '0' then
				floor_log2 := i;
				exit;
			end if;
		end loop;
		
		return floor_log2;
	end function;

	function ceil_log2(arg: unsigned) return natural is
		variable floor: natural;
	begin
		floor := floor_log2(arg);
		if arg = shift_left(to_unsigned(1, arg'length), floor) then
			return floor;
		else
			return floor + 1;
		end if;
	end function;

	signal safe_reset: std_logic;
	type packet_send_state_enum is (packet_send_state_idle, packet_send_state_command, packet_send_state_wait_for_prefetch, packet_send_state_video_header, packet_send_state_video_data);
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
	signal interlacing: std_logic_vector(3 downto 0);
	signal buffer_base_address: unsigned(memory_address_width - 1 downto 0);
	
	-- buffer row cache stuff
	constant log2_memory_data_width_in_bytes: positive := ceil_log2(to_unsigned(memory_data_width_in_bytes, 32));
	constant num_cache_rows : positive := 2;
	signal request_prefetch: std_logic;
	signal prefetch_complete: std_logic;
	constant cache_address_width: natural := ceil_log2(to_unsigned((num_cache_rows * max_frame_width * memory_bytes_per_pixel + memory_data_width - 1) / memory_data_width_in_bytes + 1, 32));
	signal prefetch_start_address: unsigned(memory_address_width - 1 downto log2_memory_data_width_in_bytes);
	signal prefetch_end_address: unsigned(memory_address_width - 1 downto log2_memory_data_width_in_bytes);
	signal cache_write_address: unsigned(cache_address_width - 1 downto 0);
	signal cache_write_enable: std_logic;
	signal cache_write_data: std_logic_vector(memory_data_width - 1 downto 0);
	signal cache_read_address: unsigned(cache_address_width - 1 downto 0);
	signal cache_read_data: std_logic_vector(memory_data_width - 1 downto 0);
	
	type memory_burst_read_state_enum is (memory_burst_read_state_idle, memory_burst_read_state_initiate, memory_burst_read_state_collect);
	signal memory_burst_read_state: memory_burst_read_state_enum;
	
	signal ready_to_send_frame: boolean;
	signal go: std_logic;
	signal horizontal_flip: std_logic;
	signal vertical_flip: std_logic;
	
	-- irq
	signal slave_irq_enable: std_logic;
	signal raw_slave_irq: std_logic;
	signal clear_slave_irq: std_logic; -- pulsed

begin
	
	assert colors_per_beat >= colors_per_pixel report "colors_per_beat < colors_per_pixel not currently supported.";
	
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
		request_prefetch = '0' and
		prefetch_complete = '0';
	
	-- generate videout out stream
	process(safe_reset, clock)	
		constant first_width_symbol_index: positive := colors_per_beat;
		constant first_height_symbol_index: positive := colors_per_beat + 4;
		constant interlacing_symbol_index: positive := colors_per_beat + 8;
		variable symbol_index: unsigned(31 downto 0);
		variable current_column: unsigned(frame_width'range);
		variable current_row: unsigned(frame_height'range);
		variable start_column: unsigned(frame_width'range);
		variable start_row: unsigned(frame_height'range);
		variable next_row: unsigned(frame_height'range);
		variable row_increment: integer range -1 to 1 := 1;
		variable column_increment: integer range -1 to 1 := 1;

		function calculate_prefetch_address(row: unsigned; column: unsigned; width: unsigned) 
			return unsigned is
		begin
			return resize((row * width + column) * memory_bytes_per_pixel / memory_data_width_in_bytes, memory_address_width - log2_memory_data_width_in_bytes);
		end function calculate_prefetch_address;

		function calculate_cache_address(row: unsigned; column: unsigned; width: unsigned) 
			return unsigned is
		begin
			return resize(calculate_prefetch_address(row, column, width), cache_address_width);
		end function calculate_cache_address;
		
		function calculate_cache_byte_offset(row: unsigned; column: unsigned; width: unsigned)
			return natural is
		begin
			return to_integer((row * width + column) * memory_bytes_per_pixel mod memory_data_width_in_bytes);
		end function calculate_cache_byte_offset;
		
		-- numeric_std only defines addition with a R of type natural, but we need integer to support negative increments
		function my_add (L: unsigned; R: integer) return unsigned is
		begin
			return L + unsigned(std_logic_vector(to_signed(R, L'length)));
		end function my_add;
		
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
			start_column := (others => '0');
			start_row := (others => '0');
			next_row := (others => '0');
			request_prefetch <= '0';
			prefetch_start_address <= (others => '0');
			prefetch_end_address <= (others => '0');
			row_increment := 0;
			column_increment := 0;
			raw_slave_irq <= '0';
			cache_read_address <= (others => '0');
		elsif rising_edge(clock) then

			video_out_valid <= '0';
			video_out_data <= (others => '0');
			video_out_startofpacket <= '0';
			video_out_endofpacket <= '0';
			beat_index <= beat_index + 1;

			if packet_send_state = packet_send_state_idle then
				symbol_index_base <= (others => '0');

				if vertical_flip = '1' then
					start_row := requested_frame_height - 1;
					row_increment := -1;
				else
					start_row := (others => '0');
					row_increment := 1;
				end if;
				current_row := start_row;

				if horizontal_flip = '1' then
					start_column := requested_frame_width - 1;
					column_increment := -1;
				else
					start_column := (others => '0');
					column_increment := 1;
				end if;
				current_column := start_column;

				next_row := my_add(current_row, row_increment);
				frame_width <= requested_frame_width;
				frame_height <= requested_frame_height;
				if ready_to_send_frame then
					prefetch_start_address <= 
						calculate_prefetch_address(current_row, to_unsigned(0, current_column'length), requested_frame_width);
					prefetch_end_address <= 
						calculate_prefetch_address(current_row, requested_frame_width - 1, requested_frame_width) + 1;
					cache_read_address <= calculate_cache_address(current_row, current_column, requested_frame_width);
					request_prefetch <= '1';
					beat_index <= (others => '0');
					packet_send_state <= packet_send_state_command;
				end if;
			else
				if packet_send_state = packet_send_state_command then
					if to_X01(video_out_ready) = '1' then
						symbol_index_base <= symbol_index_base + colors_per_beat;
						video_out_valid <= '1';

						if to_integer(beat_index) = 0 then
							video_out_data(colors_per_beat * bits_per_color - 1 downto 4) <= (others => '0');
							video_out_data(3 downto 0) <= "1111";
							video_out_startofpacket <= '1';
						else
							for i in 0 to colors_per_beat - 1 loop
								symbol_index := symbol_index_base + i;

								if symbol_index >= first_width_symbol_index and
									symbol_index < first_height_symbol_index then
									case to_integer(symbol_index) - first_width_symbol_index is
									when 3 =>
										video_out_data(i * bits_per_color + 3 downto i * bits_per_color) <= 
											std_logic_vector(frame_width(3 downto 0));
									when 2 =>
										video_out_data(i * bits_per_color + 3 downto i * bits_per_color) <= 
											std_logic_vector(frame_width(7 downto 4));
									when 1 =>
										video_out_data(i * bits_per_color + 3 downto i * bits_per_color) <= 
											std_logic_vector(frame_width(11 downto 8));
									when 0 =>
										video_out_data(i * bits_per_color + 3 downto i * bits_per_color) <= 
											std_logic_vector(frame_width(15 downto 12));
									when others =>
									end case;
								elsif symbol_index >= first_height_symbol_index and
									symbol_index < interlacing_symbol_index then
									case to_integer(symbol_index) - first_height_symbol_index is
									when 3 =>
										video_out_data(i * bits_per_color + 3 downto i * bits_per_color) <= 
											std_logic_vector(frame_height(3 downto 0));
									when 2 =>
										video_out_data(i * bits_per_color + 3 downto i * bits_per_color) <= 
											std_logic_vector(frame_height(7 downto 4));
									when 1 =>
										video_out_data(i * bits_per_color + 3 downto i * bits_per_color) <= 
											std_logic_vector(frame_height(11 downto 8));
									when 0 =>
										video_out_data(i * bits_per_color + 3 downto i * bits_per_color) <= 
											std_logic_vector(frame_height(15 downto 12));
									when others =>
									end case;
								elsif symbol_index = interlacing_symbol_index then
									video_out_data(i * bits_per_color + 3 downto i * bits_per_color) <= interlacing;
									video_out_endofpacket <= '1';
									symbol_index_base <= (others => '0');
									packet_send_state <= packet_send_state_video_header;
								end if;
							end loop;
						end if;
					end if;

				elsif packet_send_state = packet_send_state_video_header then
					if to_X01(video_out_ready) = '1' then
						beat_index <= (others => '0');
						video_out_data <= (others => '0'); -- least significant nibble must be all 0's for video packet, the rest are don't care
						video_out_startofpacket <= '1';
						video_out_valid <= '1';
						packet_send_state <= packet_send_state_wait_for_prefetch;
					end if;
				elsif packet_send_state = packet_send_state_wait_for_prefetch then
					if prefetch_complete = '0' and request_prefetch = '0' then
						packet_send_state <= packet_send_state_video_data;
					end if;

				elsif packet_send_state = packet_send_state_video_data then
					
					if to_X01(video_out_ready) = '1' then
						symbol_index_base <= symbol_index_base + colors_per_beat;
						video_out_valid <= '1';

							
						for i in 0 to (colors_per_pixel * bits_per_color) - 1 loop
							video_out_data(i) <= 
								cache_read_data(calculate_cache_byte_offset(current_row, current_column, frame_width) * 8 + i);
						end loop;
						
						-- prefetch next row
						next_row := my_add(current_row, row_increment);
						if next_row >= frame_height then
							next_row := start_row;
						end if;
						if (current_column = start_column and next_row /= start_row) then
							prefetch_start_address <= 
								calculate_prefetch_address(next_row, to_unsigned(0, current_column'length), frame_width);
							prefetch_end_address <= 
								calculate_prefetch_address(next_row, frame_width - 1, frame_width) + 1;
							assert request_prefetch = '0';
							request_prefetch <= '1';
						end if;
						-- increment column/row
						current_column := my_add(current_column, column_increment);
						if current_column >= frame_width then
							current_column := start_column;
							current_row := next_row;
							if current_row = start_row then
								video_out_endofpacket <= '1';
								raw_slave_irq <= '1';
								packet_send_state <= packet_send_state_idle;
							else
								packet_send_state <= packet_send_state_wait_for_prefetch;
							end if;
						end if;
						cache_read_address <= calculate_cache_address(current_row, current_column, frame_width);
					end if;
				end if;
			end if;
				
			-- clear request_prefetch
			if request_prefetch = '1' and prefetch_complete = '1' then
				request_prefetch <= '0';
			end if;
			-- clear irq
			if clear_slave_irq = '1' then
				raw_slave_irq <= '0';
			end if;
		end if;
	end process;
	
	-- read buffer memory
	process(safe_reset, clock)
		function num_memory_reads_completed(bytes: natural) return natural is
		begin
			return bytes / memory_data_width_in_bytes;
		end function num_memory_reads_completed;
		
		function num_memory_reads_per_row(width: positive) return natural is
		begin
			return (width * memory_bytes_per_pixel + memory_data_width_in_bytes - 1) / memory_data_width_in_bytes + 1;
		end function num_memory_reads_per_row;

		constant max_memory_reads_per_row: natural := num_memory_reads_per_row(max_frame_width);
		variable num_bytes_read: integer range 0 to 
			max_memory_reads_per_row * memory_data_width_in_bytes;
 		variable num_reads_remaining_in_burst: unsigned(memory_burstcount_width - 1 downto 0);
		variable read_request_accepted: boolean;

		procedure calculate_burst_count(variable bcount: out unsigned ) is
			variable total_reads_remaining: unsigned(prefetch_start_address'range);
		begin
			total_reads_remaining := prefetch_end_address - prefetch_start_address - num_memory_reads_completed(num_bytes_read);
			if total_reads_remaining > max_burstcount then
				bcount := to_unsigned(max_burstcount, bcount'length);
			else
				bcount := resize(total_reads_remaining, bcount'length);
			end if;
		end calculate_burst_count;

		begin
		if to_X01(safe_reset) = '1' then
			memory_address <= (others => '0');
			memory_burstcount <= (others => '0');
			memory_read <= '0';
			prefetch_complete <= '0';
			memory_burst_read_state <= memory_burst_read_state_idle;
			num_reads_remaining_in_burst := (others => '0');
			num_bytes_read := 0;
			cache_write_address <= (others => '0');
			cache_write_enable <= '0';
			cache_write_data <= (others => '0');
			read_request_accepted := false;
		elsif rising_edge(clock) then
			-- clear prefetch_complete as needed
			if prefetch_complete = '1' and request_prefetch = '0' then
				prefetch_complete <= '0';
			end if;
			
			cache_write_address <= (others => '0');
			cache_write_enable <= '0';
			cache_write_data <= (others => '0');

			if memory_burst_read_state = memory_burst_read_state_idle then
				num_bytes_read := 0;
				if request_prefetch = '1' and prefetch_complete = '0' then
					memory_burst_read_state <= memory_burst_read_state_initiate;
				end if;
			elsif memory_burst_read_state = memory_burst_read_state_initiate then

				if buffer_base_address /= 0 then
					memory_address <= std_logic_vector(buffer_base_address + resize(prefetch_start_address * memory_data_width_in_bytes, memory_address_width) + num_bytes_read);

					calculate_burst_count(num_reads_remaining_in_burst);
					
					memory_burstcount <= std_logic_vector(num_reads_remaining_in_burst);
					memory_read <= '1';
					read_request_accepted := false;
					memory_burst_read_state <= memory_burst_read_state_collect;
				end if;
				
			elsif memory_burst_read_state = memory_burst_read_state_collect then
				if to_X01(memory_waitrequest) = '0' then
					read_request_accepted := true;
					memory_read <= '0';
				end if;
				
				if to_X01(memory_readdatavalid) = '1' and read_request_accepted then
					cache_write_address <= resize(prefetch_start_address, cache_address_width) + num_memory_reads_completed(num_bytes_read);
					cache_write_enable <= '1';
					cache_write_data <= memory_readdata;
					num_bytes_read := num_bytes_read + memory_data_width_in_bytes;
					num_reads_remaining_in_burst := num_reads_remaining_in_burst - 1;
					if num_reads_remaining_in_burst = 0 then
						if num_memory_reads_completed(num_bytes_read) < prefetch_end_address - prefetch_start_address then
							memory_burst_read_state <= memory_burst_read_state_initiate;
						else
							prefetch_complete <= '1';
							memory_burst_read_state <= memory_burst_read_state_idle;
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
			interlacing <= "0011"; -- progressive
			if default_horizontal_flip then
				horizontal_flip <= '1'; 
			else
				horizontal_flip <= '0'; 
			end if;
			
			if default_vertical_flip then
				vertical_flip <= '1'; 
			else
				vertical_flip <= '0';
			end if;
			
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
					buffer_base_address <= resize(unsigned(to_X01(slave_writedata)), memory_address_width);
				when 16#8# =>
					temp_frame_width := unsigned(to_X01(slave_writedata(requested_frame_width'length - 1 downto 0)));
					if temp_frame_width <= max_frame_width then
						requested_frame_width <= temp_frame_width;
					else
						assert false report "Attempted to set frame width beyond maximum.";
					end if;
				when 16#9# =>
					requested_frame_height <= unsigned(to_X01(slave_writedata(requested_frame_height'length - 1 downto 0)));
				when 16#a# =>
					interlacing <= unsigned(to_X01(slave_writedata(interlacing'length - 1 downto 0)));
				when 16#18# =>
					horizontal_flip <= to_X01(slave_writedata(0));
					vertical_flip <= to_X01(slave_writedata(1));
				when others =>
				end case;
			end if;
			
			prev_slave_write := to_X01(slave_write);
		end if;
	end process;

	slave_irq <= raw_slave_irq and slave_irq_enable;
end fmh_framebuffer_arch;
