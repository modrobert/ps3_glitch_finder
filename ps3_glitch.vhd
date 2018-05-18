----
-- PS3 Glitch Finder v1.0
-- Copyright (C) 2010 modrobert
-- 
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
-- 
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
----
-- Brief description: 
-- Creates a glitch with various timing options.
----
-- Target Devices: xc3s400-tq144-4 (any Spartan-3 should work)
-- Dependencies: Xilinx DCM and SRL16 primitives
----
-- Notes: 
-- External clock is 25MHz crystal configured with DCM @ 200MHz 
-- giving 5ns pulse duration minimum. If you have 50MHz external
-- clock then check ps3_glitch_dcm.vhd for more info. 
-- Feel free to edit out PB4 and PB5 if you run low on buttons, 
-- still works, just have to press more. ;)
----

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_ARITH.ALL;
use IEEE.std_logic_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity ps3_glitch is
    Port ( GLITCH : out std_logic;
			  PIN_CLOCK : in std_logic;
			  PB1 : in std_logic; -- Push button 1 to trigger pulse
			  PB2 : in std_logic; -- Push button 2 to increase pulse_low_multiplier
			  PB3 : in std_logic; -- Push button 3 to increase pulse_high_multiplier
			  PB4 : in std_logic; -- Push button 4 to add X"10" to pulse_low_multiplier
			  PB5 : in std_logic; -- Push button 5 to add X"10" to pulse_high_multiplier
			  SWITCH1 : in std_logic; -- Select one-shot (off) or continous mode (on)
			  LED_L0 : out std_logic; -- LED lit when DCM is locked ok at 200mhz
			  LED_L1 : out std_logic; -- LED lit when in continous mode
			  LED_SEGMENT : out std_logic_vector(7 downto 0); -- 7-seg LED display
			  LEFT_LEDH_SELECT : out std_logic;	--		Common cathode
			  LEFT_LEDL_SELECT : out std_logic; --		have to spin
			  RIGHT_LEDH_SELECT : out std_logic; --	through all
			  RIGHT_LEDL_SELECT : out std_logic	-- 	of these.
			);
end ps3_glitch;

architecture Behavioral of ps3_glitch is

-- Digitial Clock Manager (DCM)

component ps3_glitch_dcm
   port ( CLKIN_IN        : in    std_logic; -- External clock source (crystal)
          RST_IN          : in    std_logic; -- Reset DCM ro recalibrate when lock is lost
          CLKFX_OUT       : out   std_logic; -- 200MHz in this case, giving 5ns pulse
          CLKIN_IBUFG_OUT : out   std_logic; -- Buffered external clock source untouched by DCM
          CLK0_OUT        : out   std_logic;	-- DCM generated clock, same rate as CLKIN_IN
          LOCKED_OUT      : out   std_logic); -- High when DCM is calibrated, low when lost
end component;

constant LEDREFRESH: std_logic_vector(15 downto 0) :=X"0FFF";
constant DEBOUNCE: std_logic_vector(23 downto 0) :=X"07A120"; -- 20ms @ 25MHz to play it safe
constant ZERO24: std_logic_vector(23 downto 0) :=X"000000";
constant ZERO16: std_logic_vector(15 downto 0) :=X"0000";

signal clockibuf_dcm: std_logic;
signal dcm_reset: std_logic;
signal dcm_ready: std_logic;
signal clock0_dcm: std_logic;
signal clockfx_dcm: std_logic;
signal led_data: std_logic_vector(15 downto 0);
signal button1_counter1: std_logic_vector(23 downto 0) :=X"000000";
signal button1_counter2: std_logic_vector(23 downto 0) :=X"000000";
signal button2_counter: std_logic_vector(23 downto 0) :=X"000000";
signal button3_counter: std_logic_vector(23 downto 0) :=X"000000";
signal button4_counter: std_logic_vector(23 downto 0) :=X"000000";
signal button5_counter: std_logic_vector(23 downto 0) :=X"000000";
signal button1_pushed: std_logic :='0';
signal button2_pushed: std_logic :='0';
signal button3_pushed: std_logic :='0';
signal button4_pushed: std_logic :='0';
signal button5_pushed: std_logic :='0';
signal glitch_send: std_logic :='0';
signal glitch_complete: std_logic :='1';
signal led_counter: std_logic_vector(15 downto 0) :=X"0000";
signal pulse_low_multiplier: std_logic_vector(7 downto 0) :=X"01";
signal pulse_high_multiplier: std_logic_vector(7 downto 0) :=X"01";
signal pulse_low_count: std_logic_vector(7 downto 0) :=X"00";
signal pulse_high_count: std_logic_vector(7 downto 0) :=X"00";
signal led_selector: std_logic_vector(3 downto 0) :="0001";
signal led_temp: std_logic_vector(3 downto 0);
signal hex_display: std_logic_vector(3 downto 0) :="0000";
signal dcm_reset_sent: std_logic :='0';
signal srl16_data_counter: std_logic_vector(3 downto 0) :=X"0";
signal srl16_data: std_logic;

begin

DCM_CONFIG: ps3_glitch_dcm
	port map(CLKIN_IN=>PIN_CLOCK, RST_IN=>dcm_reset, CLKFX_OUT=>clockfx_dcm, 
				CLKIN_IBUFG_OUT=>clockibuf_dcm, CLK0_OUT=>clock0_dcm, LOCKED_OUT=>dcm_ready);

-- SRL16: 16-bit shift register LUT operating on posedge of clock
-- Provides RESET for the DCM to ensure consistent frequency locking
-- Info from Xilinx PDF (xapp462): "Using Digital Clock Managers (DCMs) in Spartan-3 FPGAs"

SRL16_inst : SRL16
generic map (
	INIT => X"000F")
port map (
   Q => dcm_reset,	-- SRL data output
   A0 => '1',			-- Select[0] input
   A1 => '1',			-- Select[1] input
   A2 => '1',			-- Select[2] input
   A3 => '1',			-- Select[3] input
   CLK => clockibuf_dcm,	-- Clock input
   D => srl16_data	-- SRL data input
);

-- End of SRL16_inst instantiation

LEFT_LEDH_SELECT <= not(led_selector(3));
LEFT_LEDL_SELECT <= not(led_selector(2));
RIGHT_LEDH_SELECT <= not(led_selector(1));
RIGHT_LEDL_SELECT <= not(led_selector(0));

LED_L0 <= dcm_ready;
LED_L1 <= not(SWITCH1);

led_data(7 downto 0) <= pulse_low_multiplier;
led_data(15 downto 8) <= pulse_high_multiplier;

BUTTON_CHECK_PULSE_CONFIG: process(clockibuf_dcm)
begin
	if (rising_edge(clockibuf_dcm)) then
		if (pulse_high_multiplier=X"00") then
			pulse_high_multiplier <= X"01";
		end if;
		if (pulse_low_multiplier=X"00") then
			pulse_low_multiplier <= X"01";
		end if;		
		if (PB1='0') then
			button1_pushed <= '1';
		end if;
		if (PB2='0') then
			button2_pushed <= '1';
		end if;
		if (PB3='0') then
			button3_pushed <= '1';
		end if;
		if (PB4='0') then
			button4_pushed <= '1';
		end if;
		if (PB5='0') then
			button5_pushed <= '1';
		end if;
		if (button1_pushed='1' and PB1='0') then
			if (button1_counter1=DEBOUNCE) then
				glitch_send <= '1';
				button1_counter1 <= ZERO24;
				button1_counter2 <= ZERO24;
			else
				button1_counter1 <= button1_counter1 + 1;
			end if;
		elsif (button1_pushed='1' and PB1='1') then
			if (button1_counter2=DEBOUNCE) then
			   glitch_send <= '0';
				button1_pushed <= '0';
				button1_counter1 <= ZERO24;
				button1_counter2 <= ZERO24;
			else
				button1_counter2 <= button1_counter2 + 1;
			end if;
		end if;
		if (button2_pushed='1' and PB2='1') then
			if (button2_counter=DEBOUNCE) then
				pulse_high_multiplier <= pulse_high_multiplier + 1;
				button2_pushed <= '0';
				button2_counter <= ZERO24;
			else
				button2_counter <= button2_counter + 1;
			end if;
		end if;
		if (button3_pushed='1' and PB3='1') then
			if (button3_counter=DEBOUNCE) then
				pulse_low_multiplier <= pulse_low_multiplier + 1;
				button3_pushed <= '0';
				button3_counter <= ZERO24;
			else
				button3_counter <= button3_counter + 1;
			end if;
		end if;
		if (button4_pushed='1' and PB4='1') then
			if (button4_counter=DEBOUNCE) then
				pulse_high_multiplier <= pulse_high_multiplier + X"10";
				button4_pushed <= '0';
				button4_counter <= ZERO24;
			else
				button4_counter <= button4_counter + 1;
			end if;
		end if;
		if (button5_pushed='1' and PB5='1') then
			if (button5_counter=DEBOUNCE) then
				pulse_low_multiplier <= pulse_low_multiplier + X"10";
				button5_pushed <= '0';
				button5_counter <= ZERO24;
			else
				button5_counter <= button5_counter + 1;
			end if;
		end if;
	end if;
end process;

PULSE_GENERATOR: process(clockfx_dcm)
-- should be cycle exact now
-- tested with logic analyzer
begin
	if (rising_edge(clockfx_dcm)) then
		if (glitch_send='1' and dcm_ready='1') then
			glitch_complete <= '0';
			if (pulse_low_count < pulse_low_multiplier) then
				GLITCH <= '0';
				pulse_low_count <= pulse_low_count + 1;
			elsif (pulse_high_count < pulse_high_multiplier) then
				GLITCH <= '1';
				pulse_high_count <= pulse_high_count + 1;
			elsif (SWITCH1='0') then
				GLITCH <= '0';
				pulse_high_count <= X"00";
				pulse_low_count <= X"01"; -- already spent one clock cycle low
			end if;
		elsif (glitch_complete='0') then
			if (SWITCH1='0') then
				if (pulse_low_count < pulse_low_multiplier) then
					GLITCH <= '0';
					pulse_low_count <= pulse_low_count + 1;
				elsif (pulse_high_count < pulse_high_multiplier) then
					GLITCH <= '1';
					pulse_high_count <= pulse_high_count + 1;
				else
					pulse_high_count <= X"00";
					pulse_low_count <= X"00";
					glitch_complete <= '1';				
				end if;
			else
				pulse_high_count <= X"00";
				pulse_low_count <= X"00";
				glitch_complete <= '1';
			end if;
		else
			GLITCH <= 'Z';
		end if;
	end if;
end process;

LED_SCANNER: process(clockibuf_dcm)
begin
	if (rising_edge(clockibuf_dcm)) then
		if (led_counter=LEDREFRESH) then
			led_counter <= ZERO16;
			led_temp <= led_selector(0) & led_selector(3 downto 1); -- ror
			led_selector <= led_temp;
		else  
			led_counter <= led_counter + 1; 
		end if;
	end if;
end process;

DCM_LOCK_HANDLER: process(clockibuf_dcm)
begin
	if (rising_edge(clockibuf_dcm)) then
		if (dcm_ready='0') then
			if (dcm_reset_sent='0') then
				if (srl16_data_counter=X"F") then
					srl16_data <= '0';
					srl16_data_counter <= X"0";
					dcm_reset_sent <= '1';
				else
					srl16_data <= '1';
					srl16_data_counter <= srl16_data_counter + 1;
				end if;
			end if;
		else
			srl16_data <= '0';
			dcm_reset_sent <= '0';
		end if;
	end if;
end process;

-- Four digit "seven-segment" LED display with common cathode

with led_selector select
	hex_display <= led_data(15 downto 12) when "1000",
	led_data(11 downto 8) when "0100",
	led_data(7 downto 4) when "0010",
	led_data(3 downto 0) when others;

-- Segment map
-- LED_SEGMENT(0) = f
-- LED_SEGMENT(1) = a
-- LED_SEGMENT(2) = b
-- LED_SEGMENT(3) = dp ;decimal point
-- LED_SEGMENT(4) = c
-- LED_SEGMENT(5) = d
-- LED_SEGMENT(6) = e
-- LED_SEGMENT(7) = g

with hex_display select
	LED_SEGMENT <= "00010100" when "0001",	--1
		"11100110" when "0010",	--2
		"10110110" when "0011",	--3
		"10010101" when "0100",	--4
		"10110011" when "0101",	--5
		"11110011" when "0110",	--6
		"00010110" when "0111",	--7
		"11110111" when "1000",	--8
		"10010111" when "1001",	--9
		"11010111" when "1010",	--A
		"11110001" when "1011",	--b
		"11100000" when "1100",	--C
		"11110100" when "1101",	--d
		"11100011" when "1110",	--E
		"11000011" when "1111",	--F
		"01110111" when others;	--0
	
end Behavioral;
