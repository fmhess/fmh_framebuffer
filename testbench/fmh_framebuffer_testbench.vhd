-- Author: Frank Mori Hess fmh6jj@gmail.com
-- Copyright 2020 Fluke Corporation

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fmh_framebuffer_testbench is
end fmh_framebuffer_testbench;
     
architecture behav of fmh_framebuffer_testbench is
	constant bits_per_color: positive := 8;
	constant colors_per_beat: positive := 4;
	constant colors_per_pixel: positive := 4;
	constant memory_address_width : positive := 32;
	constant memory_burstcount_width : positive := 4;
	constant memory_data_width : positive := 64;
	constant memory_bytes_per_pixel_per_plane: positive := 4;
	
	constant buffer_base_address: unsigned(memory_address_width - 1 downto 0) := X"80000000";
	constant frame_width: unsigned(15 downto 0) := to_unsigned(100, 16);
	constant frame_height: unsigned(15 downto 0) := to_unsigned(40, 16);
	
	signal clock : std_logic;
	signal reset : std_logic;
	signal memory_address: std_logic_vector(memory_address_width - 1 downto 0);
	signal memory_burstcount: std_logic_vector(memory_burstcount_width - 1 downto 0);
	signal memory_readdata: std_logic_vector(memory_data_width - 1 downto 0);
	signal memory_read: std_logic;
	signal memory_readdatavalid: std_logic;
	signal memory_waitrequest: std_logic;
	signal slave_address: std_logic_vector(4 downto 0);
	signal slave_readdata: std_logic_vector(31 downto 0);
	signal slave_read: std_logic;
	signal slave_writedata: std_logic_vector(31 downto 0);
	signal slave_write: std_logic;
	signal slave_irq: std_logic;
	signal video_out_ready: std_logic;
	signal video_out_valid: std_logic;
	signal video_out_data: std_logic_vector(bits_per_color * colors_per_beat - 1 downto 0);
	signal video_out_startofpacket: std_logic;
	signal video_out_endofpacket: std_logic;

	constant clock_half_period : time := 8 ns;

	shared variable test_finished : boolean := false;

	procedure wait_for_ticks (num_clock_cycles : in integer) is 
	begin
		for i in 1 to num_clock_cycles loop
			wait until rising_edge(clock);
		end loop;
	end procedure wait_for_ticks;
	
	procedure host_write (addr: in natural;
		data : in std_logic_vector) is
	begin
		wait until rising_edge(clock);

		slave_write <= '1';
		slave_writedata <= data;
		slave_address <= std_logic_vector(to_unsigned(addr, slave_address'length));
	
		wait until rising_edge(clock);

		slave_write <= '0';

		wait until rising_edge(clock);
	end procedure host_write;

	begin
	my_framebuffer : entity work.fmh_framebuffer
		generic map (
			bits_per_color => bits_per_color,
			colors_per_beat => colors_per_beat,
			colors_per_pixel => colors_per_pixel,
			memory_address_width => memory_address_width,
			memory_burstcount_width => memory_burstcount_width,
			memory_data_width => memory_data_width,
			memory_bytes_per_pixel_per_plane => memory_bytes_per_pixel_per_plane,
			max_frame_width => 200,
			default_horizontal_flip => false,
			default_vertical_flip => false
		)
		port map (
			clock => clock,
			reset => reset,
			memory_address => memory_address,
			memory_burstcount => memory_burstcount,
			memory_readdata => memory_readdata,
			memory_read => memory_read,
			memory_readdatavalid => memory_readdatavalid,
			memory_waitrequest => memory_waitrequest,
			slave_address => slave_address,
			slave_readdata => slave_readdata,
			slave_read => slave_read,
			slave_writedata => slave_writedata,
			slave_write => slave_write,
			slave_irq => slave_irq,
			video_out_ready => video_out_ready,
			video_out_valid => video_out_valid,
			video_out_data => video_out_data,
			video_out_startofpacket => video_out_startofpacket,
			video_out_endofpacket => video_out_endofpacket
		);
	
	-- clock
	process
	begin
		if(test_finished) then
			wait;
		end if;
		
		clock <= '0';
		wait for clock_half_period;
		clock <= '1';
		wait for clock_half_period;
	end process;

	-- buffer RAM process
	process(clock, reset)
		constant memory_width_in_pixels: natural := memory_data_width / (memory_bytes_per_pixel_per_plane * 8);
		variable test_value: unsigned(memory_bytes_per_pixel_per_plane * 8 - 1 downto 0);
		variable requested_burst_count: unsigned(memory_burstcount'range);
		variable burst_count: unsigned(memory_burstcount'range);
		variable delay_count: integer;
		variable burst_address: unsigned(memory_address_width - 1 downto 0);
		variable read_in_progress: boolean;
		variable beyond_end_of_buffer: unsigned(memory_address_width - 1 downto 0);
	begin
		if reset = '1' then
			memory_readdata <= (others => '0');
			memory_readdatavalid <= '0';
			memory_waitrequest <= '1';
			test_value := (others => '0');
			requested_burst_count := (others => '0');
			burst_count := (others => '0');
			burst_address := (others => '0');
			read_in_progress := false;
			beyond_end_of_buffer := (others => '0');
		elsif rising_edge(clock) then
			memory_readdata <= (others => '0');
			memory_readdatavalid <= '0';

			if to_X01(memory_read) = '1' and read_in_progress = false then
                memory_waitrequest <= '0';
			end if;

			if to_X01(memory_read) = '1' and memory_waitrequest = '0' then
				requested_burst_count := unsigned(memory_burstcount);
				burst_count := (others => '0');
				burst_address := unsigned(memory_address);
				assert burst_address >= buffer_base_address;
				delay_count := 0;
				memory_waitrequest <= '1';
				read_in_progress := true;
			end if;
			
			if read_in_progress then
				delay_count := (delay_count + 1) mod 6;
				if delay_count /= 0 then
					memory_readdatavalid <= '0';
				else

					memory_readdatavalid <= '1';				
					
					if burst_count < requested_burst_count then
						memory_readdatavalid <= '1';

						-- assert that the address of the first byte in the read is inside the framebuffer
						beyond_end_of_buffer := buffer_base_address + resize((frame_width * frame_height) * memory_bytes_per_pixel_per_plane, memory_address_width);
						if burst_address >= beyond_end_of_buffer then
								assert false;
						end if;
						
						for i in 0 to memory_width_in_pixels - 1 loop
							test_value := resize(unsigned(burst_address) - buffer_base_address, test_value'length) / memory_bytes_per_pixel_per_plane;

							memory_readdata((i + 1) * memory_bytes_per_pixel_per_plane * 8 - 1 downto i * memory_bytes_per_pixel_per_plane * 8) <=
								std_logic_vector(test_value);
							burst_address := burst_address + memory_bytes_per_pixel_per_plane;	
						end loop;
						burst_count := burst_count + 1;
					else
						read_in_progress := false;
					end if;
				end if;
			else
				delay_count := 0;
			end if;
		end if;
	end process;
	
	-- Avalon ST Video process
	process(clock, reset)
		variable beat: natural;
		variable in_video_packet: boolean;
	begin
		if reset = '1' then
			beat := 0;
			video_out_ready <= '0';
			in_video_packet := false;
		elsif rising_edge(clock) then
			video_out_ready <= '1';
			if in_video_packet = false then
				beat := 0;
			end if;
			
			if in_video_packet and video_out_valid = '1' then
				assert unsigned(video_out_data) = beat report "Unexpected video_out_data=" & integer'image(to_integer(unsigned(video_out_data))) & " on beat " & integer'image(beat);
				beat := beat + 1;
			end if;			
			if video_out_startofpacket = '1' and video_out_data(3 downto 0) = X"0" then
				in_video_packet := true;
			end if;
			if video_out_endofpacket = '1' then
				in_video_packet := false;
			end if;
		end if;
	end process;
	
	-- main test process
	process
	begin
		reset <= '1';
		slave_read <= '0';
		slave_write <= '0';
		slave_writedata <= (others => '0');
		slave_address <= (others => '0');
		
		wait until rising_edge(clock);
		
		reset <= '0';
		wait until rising_edge(clock);

 		host_write(8, std_logic_vector(resize(frame_width, 32))); -- frame width
 		host_write(9, std_logic_vector(resize(frame_height, 32))); -- frame height
		host_write(4, std_logic_vector(buffer_base_address)); -- base address
		host_write(0, X"00000003"); -- go and enable irq

		for i in 0 to 1 loop
			wait until slave_irq = '1';
			assert false report "completed a frame" severity note;
			host_write(2, X"00000001"); -- clear irq
		end loop;
		
		wait_for_ticks(2);
		assert false report "end of test" severity note;
		test_finished := true;
		wait;
	end process;
end behav;
