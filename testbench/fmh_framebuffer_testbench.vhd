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
	constant memory_data_width : positive := 32;
	constant slave_address_width: positive := 5;
	constant slave_data_width: positive := 32;
	
	signal clock : std_logic;
	signal reset : std_logic;
	signal memory_address: std_logic_vector(memory_address_width - 1 downto 0);
	signal memory_burstcount: std_logic_vector(memory_burstcount_width - 1 downto 0);
	signal memory_readdata: std_logic_vector(memory_data_width - 1 downto 0);
	signal memory_read: std_logic;
	signal memory_readdatavalid: std_logic;
	signal memory_waitrequest: std_logic;
	signal slave_address: std_logic_vector(slave_address_width - 1 downto 0);
	signal slave_readdata: std_logic_vector(slave_data_width - 1 downto 0);
	signal slave_read: std_logic;
	signal slave_writedata: std_logic_vector(slave_data_width - 1 downto 0);
	signal slave_write: std_logic;
	signal slave_irq: std_logic;
	signal video_out_ready: std_logic;
	signal video_out_valid: std_logic;
	signal video_out_data: std_logic_vector(bits_per_color * colors_per_beat - 1 downto 0);
	signal video_out_startofpacket: std_logic;
	signal video_out_endofpacket: std_logic;

	constant clock_half_period : time := 8 ns;

	shared variable test_finished : boolean := false;

	begin
	my_framebuffer : entity work.fmh_framebuffer
		generic map (
			bits_per_color => bits_per_color,
			colors_per_beat => colors_per_beat,
			colors_per_pixel_per_plane => colors_per_pixel_per_plane,
			memory_address_width => memory_address_width,
			memory_burstcount_width => memory_burstcount_width,
			memory_data_width => memory_data_width,
			slave_address_width => slave_address_width,
			slave_data_width => slave_data_width
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
	
	process
	begin
		reset <= '1';
		wait until rising_edge(clock);
		
		reset <= '0';
		wait until rising_edge(clock);

		wait until rising_edge(clock);
		assert false report "end of test" severity note;
		test_finished := true;
		wait;
	end process;
end behav;
