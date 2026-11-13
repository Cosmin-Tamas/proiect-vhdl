----------------------------------------------------------------------------------
-- File: srt_divider_top.vhd
-- Description: Structural Top-Level module for the 16-bit Signed Radix-4 SRT Divider.
--              Instantiates and interconnects the Control Unit (CU) and Execution Unit (EU).
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity srt_divider_top is
    generic (
        DATA_WIDTH : integer := 16
    );
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        start        : in  std_logic;
        dividend     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        divisor      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        ready        : out std_logic;
        done         : out std_logic;
        div_zero_err : out std_logic;
        quotient     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        remainder    : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity srt_divider_top;

architecture Structural of srt_divider_top is

    -- Component declaration for Control Unit (CU)
    component srt_radix4_cu is
        port (
            clk          : in  std_logic;
            reset        : in  std_logic;
            start        : in  std_logic;
            div_by_zero  : in  std_logic;
            d_norm_done  : in  std_logic;
            count_zero   : in  std_logic;
            p4_top       : in  std_logic_vector(6 downto 0);
            d_top        : in  std_logic_vector(2 downto 0);
            init_regs    : out std_logic;
            norm_en      : out std_logic;
            exec_en      : out std_logic;
            corr_en      : out std_logic;
            q_digit      : out std_logic_vector(2 downto 0);
            done         : out std_logic;
            ready        : out std_logic
        );
    end component;

    -- Component declaration for Execution Unit (EU)
    component srt_radix4_eu is
        generic (
            DATA_WIDTH : integer := 16
        );
        port (
            clk          : in  std_logic;
            reset        : in  std_logic;
            dividend     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            divisor      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            init_regs    : in  std_logic;
            norm_en      : in  std_logic;
            exec_en      : in  std_logic;
            corr_en      : in  std_logic;
            q_digit      : in  std_logic_vector(2 downto 0);
            div_by_zero  : out std_logic;
            d_norm_done  : out std_logic;
            count_zero   : out std_logic;
            p4_top       : out std_logic_vector(6 downto 0);
            d_top        : out std_logic_vector(2 downto 0);
            quotient     : out std_logic_vector(DATA_WIDTH-1 downto 0);
            remainder    : out std_logic_vector(DATA_WIDTH-1 downto 0);
            div_zero_err : out std_logic
        );
    end component;

    -- Internal interconnection signals between CU and EU
    signal sig_div_by_zero : std_logic;
    signal sig_d_norm_done : std_logic;
    signal sig_count_zero  : std_logic;
    signal sig_p4_top      : std_logic_vector(6 downto 0);
    signal sig_d_top       : std_logic_vector(2 downto 0);
    signal sig_init_regs   : std_logic;
    signal sig_norm_en     : std_logic;
    signal sig_exec_en     : std_logic;
    signal sig_corr_en     : std_logic;
    signal sig_q_digit     : std_logic_vector(2 downto 0);

begin

    -- Instantiate Control Unit (CU)
    CU_INST : srt_radix4_cu
        port map (
            clk          => clk,
            reset        => reset,
            start        => start,
            div_by_zero  => sig_div_by_zero,
            d_norm_done  => sig_d_norm_done,
            count_zero   => sig_count_zero,
            p4_top       => sig_p4_top,
            d_top        => sig_d_top,
            init_regs    => sig_init_regs,
            norm_en      => sig_norm_en,
            exec_en      => sig_exec_en,
            corr_en      => sig_corr_en,
            q_digit      => sig_q_digit,
            done         => done,
            ready        => ready
        );

    -- Instantiate Execution Unit (EU)
    EU_INST : srt_radix4_eu
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk          => clk,
            reset        => reset,
            dividend     => dividend,
            divisor      => divisor,
            init_regs    => sig_init_regs,
            norm_en      => sig_norm_en,
            exec_en      => sig_exec_en,
            corr_en      => sig_corr_en,
            q_digit      => sig_q_digit,
            div_by_zero  => sig_div_by_zero,
            d_norm_done  => sig_d_norm_done,
            count_zero   => sig_count_zero,
            p4_top       => sig_p4_top,
            d_top        => sig_d_top,
            quotient     => quotient,
            remainder    => remainder,
            div_zero_err => div_zero_err
        );

end architecture Structural;