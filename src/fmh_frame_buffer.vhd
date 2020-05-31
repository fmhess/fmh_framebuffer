-- Author: Frank Mori Hess fmh6jj@gmail.com
-- Copyright 2020 Fluke Corporation

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity fmh_frame_buffer is
	generic(
		bits_per_symbol: positive := 8;
		symbols_per_pixel_per_plane: positive := 4;
		symbols_per_beat: positive := 4;
		beats_per_pixel: positive := 1;
		memory_address_width: positive := 32;
		memory_burstcount_width: positive := 4;
		memory_data_width: positive := 64;
		slave_address_width: positive := 5;
		slave_data_width: positive := 32
	);
	port(
		clock: in std_logic;
		reset: in std_logic;
		
		-- avalon master for buffer memory
		memory_clock: in std_logic;
		memory_reset: in std_logic;
		memory_address: out std_logic_vector(memory_address_width - 1 downto 0);
		memory_burstcount: out std_logic_vector(memory_burstcount_width - 1 downto 0);
		memory_readdata: in std_logic_vector(memory_data_width - 1 downto 0);
		memory_read: out std_logic;
		memory_readdatavalid: in std_logic;
		memory_waitrequest: in std_logic;
		
		-- avalon slave
		slave_address: in std_logic_vector(slave_address_width - 1 downto 0);
		slave_readdata: out std_logic_vector(slave_data_width - 1 downto 0);
		slave_read: in std_logic;
		slave_writedata: in std_logic_vector(slave_data_width - 1 downto 0);
		slave_write: in std_logic;
		slave_irq: out std_logic;
		
		-- avalon st video out
		video_out_ready: in std_logic;
		video_out_valid: out std_logic;
		video_out_data: out std_logic_vector(bits_per_symbol * symbols_per_beat - 1 downto 0);
		video_out_startofpacket: out std_logic;
		video_out_endofpacket: out std_logic
	);
end fmh_frame_buffer;

architecture fmh_frame_buffer_arch of fmh_frame_buffer is

	signal safe_reset: std_logic;
	type packet_send_state_enum is (packet_send_state_idle, packet_send_state_command, packet_send_state_video);
	signal packet_send_state: packet_send_state_enum;
	signal frame_width: unsigned(15 downto 0);
	signal frame_height: unsigned(15 downto 0);
	signal beat_index: unsigned(31 downto 0);
	signal symbol_index_base: unsigned(31 downto 0);
	constant interlacing: std_logic_vector(3 downto 0) := "0010"; -- progressive
begin
	-- sync release of reset
	process (reset, clock)
	begin
		if to_X01(reset) = '1' then
			safe_reset <= '1';
		elsif rising_edge(clock) then
			safe_reset <= '0';
		end if;
	end process;
 
	-- generate videout out stream
	process(safe_reset, clock)
		constant first_width_symbol_index: positive := symbols_per_beat;
		constant first_height_symbol_index: positive := symbols_per_beat + 4;
		constant interlacing_symbol_index: positive := symbols_per_beat + 8;
		variable symbol_index: unsigned(31 downto 0);
		variable current_column: unsigned(15 downto 0);
		variable current_row: unsigned(15 downto 0);
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
				frame_width <= to_unsigned(800, frame_width'length); -- FIXME: hard coding for now
				frame_height <= to_unsigned(480, frame_width'length); -- FIXME: hard coding for now
				if to_X01(video_out_ready) = '1' then
					packet_send_state <= packet_send_state_command;
				end if;
			else
				if packet_send_state = packet_send_state_command then
					if to_X01(video_out_ready) = '1' then
						beat_index <= beat_index + 1;
						symbol_index_base <= symbol_index_base + symbols_per_beat;
						video_out_valid <= '1';

						if to_integer(beat_index) = 0 then
							video_out_data <= (others => '1'); -- least significant nibble must be all 1's for control packet, the rest are don't care
							video_out_startofpacket <= '1';
							video_out_endofpacket <= '0';
						else
							video_out_data <= (others => '0');
							video_out_startofpacket <= '0';
							video_out_endofpacket <= '0';
							for i in 0 to symbols_per_beat - 1 loop
								symbol_index := symbol_index_base + i;

								if symbol_index >= first_width_symbol_index and
									symbol_index < first_height_symbol_index then
									video_out_data(i * bits_per_symbol + 3 downto i * bits_per_symbol) <= 
										std_logic_vector(frame_width(15 - (to_integer(symbol_index) - first_width_symbol_index) * 4 
											downto 12 - (to_integer(symbol_index) - first_width_symbol_index) * 4));
								elsif symbol_index >= first_height_symbol_index and
									symbol_index < interlacing_symbol_index then
									video_out_data(i * bits_per_symbol + 3 downto i * bits_per_symbol) <= 
										std_logic_vector(frame_height(15 - (to_integer(symbol_index) - first_height_symbol_index) * 4 
											downto 12 - (to_integer(symbol_index) - first_height_symbol_index) * 4));
								elsif symbol_index = interlacing_symbol_index then
									video_out_data(i * bits_per_symbol + 3 downto i * bits_per_symbol) <= interlacing;
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
					if to_X01(video_out_ready) = '1' then
						beat_index <= beat_index + 1;
						symbol_index_base <= symbol_index_base + symbols_per_beat;
						video_out_valid <= '1'; -- FIXME: take into account availablity of framebuffer data

						if to_integer(beat_index) = 0 then
							video_out_data <= (others => '0'); -- least significant nibble must be all 0's for video packet, the rest are don't care
							video_out_startofpacket <= '1';
							video_out_endofpacket <= '0';
						else
							video_out_data <= (others => '0');
							video_out_startofpacket <= '0';
							video_out_endofpacket <= '0';
							video_out_data(bits_per_symbol - 1 downto 0) <= 
								std_logic_vector(current_column(bits_per_symbol - 1 downto 0)); -- blue according to column
							video_out_data(2 * bits_per_symbol - 1 downto bits_per_symbol) <= 
								std_logic_vector(current_row(bits_per_symbol - 1 downto 0)); -- green according to row

							-- increment column/row
							current_column := current_column + 1;
							if current_column >= frame_width then
								current_column := (others => '0');
								current_row := current_row + 1;
								if current_row >= frame_height then
									current_row := (others => '0');
									video_out_endofpacket <= '1';
									packet_send_state <= packet_send_state_idle;
								end if;
							end if;
						end if;
						
					else
						video_out_valid <= '0';
					end if;
				end if;
			end if;
		end if;
	end process;
	
	-- unimplemented stubs
	memory_address <= (others => '0');
	memory_burstcount <= (others => '0');
	memory_read <= '0';
	slave_readdata <= (others => '0');
	slave_irq <= '0';
end fmh_frame_buffer_arch;
