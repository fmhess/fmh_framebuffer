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
	constant colors_per_pixel_per_plane: positive := 4;
	constant memory_address_width : positive := 32;
	constant memory_burstcount_width : positive := 4;
	constant memory_data_width : positive := 64;
	constant memory_bytes_per_pixel_per_plane: positive := 4;
	
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
			colors_per_pixel_per_plane => colors_per_pixel_per_plane,
			memory_address_width => memory_address_width,
			memory_burstcount_width => memory_burstcount_width,
			memory_data_width => memory_data_width,
			memory_bytes_per_pixel_per_plane => memory_bytes_per_pixel_per_plane,
			max_frame_width => 400
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
		variable burst_count: unsigned(memory_burstcount'range);
		variable prev_memory_read: std_logic;
	begin
		if reset = '1' then
			memory_readdata <= (others => '0');
			memory_readdatavalid <= '0';
			memory_waitrequest <= '0';
			test_value := (others => '0');
			burst_count := (others => '0');
			prev_memory_read := '0';
		elsif rising_edge(clock) then
			memory_readdata <= (others => '0');
			memory_readdatavalid <= '0';
			memory_waitrequest <= '0';
			
			if to_X01(memory_read) = '1' then
				if prev_memory_read = '0' then
					burst_count := unsigned(memory_burstcount);
				end if;
				
				if burst_count > 0 then
					memory_readdatavalid <= '1';
					for i in 0 to memory_width_in_pixels - 1 loop
						memory_readdata((i + 1) * memory_bytes_per_pixel_per_plane * 8 - 1 downto i * memory_bytes_per_pixel_per_plane * 8) <=
							std_logic_vector(test_value);
						test_value := test_value + 1;
					end loop;
					burst_count := burst_count - 1;
				end if;
			end if;
			
			prev_memory_read := to_X01(memory_read);
		end if;
	end process;
	
	-- Avalon ST Video process
	process(clock, reset)
	begin
		if reset = '1' then
			video_out_ready <= '0';
		elsif rising_edge(clock) then
			video_out_ready <= '1';
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

		host_write(8, X"00000028"); -- frame width
		host_write(9, X"0000000a"); -- frame height
		host_write(4, X"80000000"); -- base address
		host_write(0, X"00000003"); -- go and enable irq

		wait until slave_irq = '1';

		host_write(2, X"00000001"); -- clear irq
		
		wait_for_ticks(2);
		assert false report "end of test" severity note;
		test_finished := true;
		wait;
	end process;
end behav;
