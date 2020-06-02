-- Author: Frank Mori Hess fmh6jj@gmail.com
-- Copyright 2020 Fluke Corporation


library	IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fmh_framebuffer_ocram is
	generic (
		address_width: positive;
		data_width: positive
	);
	port (
		clock: in std_logic;
		write_enable: in std_logic;
		write_address: in	unsigned(address_width - 1 downto 0);
		write_data: in std_logic_vector(data_width - 1 downto 0);
		read_address: in	unsigned(address_width - 1 downto 0);
		read_data: out std_logic_vector(data_width - 1 downto 0)
	);
end entity;

architecture arch of fmh_framebuffer_ocram is

	type ram_type is array(0 to 2 ** address_width - 1) of std_logic_vector(data_width - 1 downto 0);
	signal ram: ram_type;

	begin
		process (clock)
		begin
			if rising_edge(clock) then
				if write_enable = '1' then
					ram(to_integer(write_address)) <= write_data;
				end if;
			end if;
		end process;

		read_data <= ram(to_integer(read_address));
end architecture;
