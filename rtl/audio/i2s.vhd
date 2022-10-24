
-- I2S Pi0 + ZX Spectrum Next Interface
-- Copyright 2020 Alvin Albrecht
--
-- This file is part of the ZX Spectrum Next Project
-- <https://gitlab.com/SpectrumNext/ZX_Spectrum_Next_FPGA/tree/master/cores>
--
-- The ZX Spectrum Next FPGA source code is free software: you can 
-- redistribute it and/or modify it under the terms of the GNU General 
-- Public License as published by the Free Software Foundation, either 
-- version 3 of the License, or (at your option) any later version.
--
-- The ZX Spectrum Next FPGA source code is distributed in the hope 
-- that it will be useful, but WITHOUT ANY WARRANTY; without even the 
-- implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR 
-- PURPOSE.  See the GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with the ZX Spectrum Next FPGA source code.  If not, see 
-- <https://www.gnu.org/licenses/>.

-- Reference:
--  <https://web.archive.org/web/20070102004400/http://www.nxp.com/acrobat_download/various/I2SBUS.pdf>
--
-- Sample Rate = SR = i_CLK / 2^(CLK_DIV_PRE) / (i_CLK_DIV+1) / LR_WIDTH / 4
--             = 538461 / (i_CLK_DIV+1)
--
-- i_CLK_DIV   = (i_CLK / 2^(CLK_DIV_PRE) / SR / LR_WIDTH / 4) - 1
--             = 538461 / SR - 1
--
-- This is a two-way interface allowing the exchange of stereo audio between
-- the zx next and the pi.
--
-- Audio from the pi is given the same loudness as a single 8-bit dac channel.
-- The unsigned range of pcm therefore covers 10 bits per stereo channel.
--
-- Audio generated by the zx next is unsigned 13 bits per stereo channel.
--
-- i2s exchanges signed audio.

-- Note: Restricted to slave mode only

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity zx_i2s is
   port
   (
      i_reset        : in std_logic;
      
      i_CLK          : in std_logic;
--    i_CLK_DIV      : in std_logic_vector(7 downto 0);
      
--    i_slave_mode   : in std_logic;   -- 1 = slave, external clock used

      -- slave mode (incoming clock signals, synchronized)
      
      i_i2s_sck      : in std_logic;
      i_i2s_ws       : in std_logic;
      
      -- outgoing clock signals (master or slave)
      
      o_i2s_sck      : out std_logic;
      o_i2s_ws       : out std_logic;
      o_i2s_wsp      : out std_logic;

      -- zx next audio to pi
      
      i_audio_zxn_L  : in std_logic_vector(12 downto 0);
      i_audio_zxn_R  : in std_logic_vector(12 downto 0);
      o_i2s_sd_pi    : out std_logic;

      -- pi audio to zx next
      
      i_i2s_sd_pi    : in std_logic;
      o_audio_pi_L   : out std_logic_vector(9 downto 0);
      o_audio_pi_R   : out std_logic_vector(9 downto 0)
   );
end entity;

architecture rtl of zx_i2s is

   signal i2s_sck       : std_logic;
   signal i2s_ws        : std_logic;
   signal i2s_wsp       : std_logic;

   signal m_i2s_sck     : std_logic;
   signal m_i2s_ws      : std_logic;
   signal m_i2s_wsp     : std_logic;

   signal s_i2s_sck     : std_logic;
   signal s_i2s_ws      : std_logic;
   signal s_i2s_wsp     : std_logic;

   signal audio_pi_L    : std_logic_vector(12 downto 0);
   signal audio_pi_R    : std_logic_vector(12 downto 0);
   
   signal audio_zxn_L   : std_logic_vector(12 downto 0);
   signal audio_zxn_R   : std_logic_vector(12 downto 0);

begin

-- -- i2s master
   
-- i2s_master_mod : entity work.i2s_master
-- generic map
-- (
--    CLK_DIV_PRE    => 0,
--    CLK_DIV_MBIT   => 7,
--    LR_WIDTH       => 13,
--    LR_WIDTH_MBIT  => 3
-- )
-- port map
-- (
--    i_reset        => i_reset or i_slave_mode,
--    
--    i_CLK          => i_CLK,
--    i_CLK_DIV      => i_CLK_DIV,
--
--    o_i2s_sck      => m_i2s_sck,
--    o_i2s_ws       => m_i2s_ws,
--    o_i2s_wsp      => m_i2s_wsp
--   );
   
   -- i2s slave
   
   i2s_slave_mod : entity work.i2s_slave
   port map
   (
--    i_reset        => i_reset or not i_slave_mode,
--    
--    i_CLK          => i_CLK,
--    
      i_i2s_sck      => i_i2s_sck,
      i_i2s_ws       => i_i2s_ws,
      
      o_i2s_sck      => s_i2s_sck,
      o_i2s_ws       => s_i2s_ws,
      o_i2s_wsp      => s_i2s_wsp
   );
   
   -- master or slave
   
   i2s_sck <= s_i2s_sck; -- when i_slave_mode = '1' else m_i2s_sck;
   i2s_ws <= s_i2s_ws; -- when i_slave_mode = '1' else m_i2s_ws;
   i2s_wsp <= s_i2s_wsp; -- when i_slave_mode = '1' else m_i2s_wsp;
   
   o_i2s_sck <= i2s_sck;
   o_i2s_ws <= i2s_ws;
   o_i2s_wsp <= i2s_wsp;
   
   -- i2s receive from pi
   
   i2s_receiver_mod : entity work.i2s_receive
   generic map
   (
      LR_WIDTH       => 13,
      LR_WIDTH_MBIT  => 3
   )
   port map
   (
      i_reset        => i_reset,
      i_CLK          => i_CLK,
      
      i_i2s_sck      => i2s_sck,
      i_i2s_ws       => i2s_ws,
      i_i2s_wsp      => i2s_wsp,
      i_i2s_sd       => i_i2s_sd_pi,
      
      o_i2s_L        => audio_pi_L,
      o_i2s_R        => audio_pi_R
   );
   
   process (i_CLK)
   begin
      if rising_edge(i_CLK) then
         o_audio_pi_L <= (not audio_pi_L(12)) & audio_pi_L(11 downto 3);
         o_audio_pi_R <= (not audio_pi_R(12)) & audio_pi_R(11 downto 3);
      end if;
   end process;
   
   -- i2s transmit to pi
   
   audio_zxn_L <= (not i_audio_zxn_L(12)) & i_audio_zxn_L(11 downto 0);
   audio_zxn_R <= (not i_audio_zxn_R(12)) & i_audio_zxn_R(11 downto 0);
   
   i2s_transmit_mod : entity work.i2s_transmit
   generic map
   (
      LR_WIDTH       => 13
   )
   port map
   (
      i_reset        => i_reset,
      i_CLK          => i_CLK,
      
      i_i2s_sck      => i2s_sck,
      i_i2s_ws       => i2s_ws,
      i_i2s_wsp      => i2s_wsp,
      o_i2s_sd       => o_i2s_sd_pi,
      
      i_i2s_L        => audio_zxn_L,
      i_i2s_R        => audio_zxn_R
   );

end architecture;
