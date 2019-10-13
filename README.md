# HD6309 Bootrom

The source code for the HD6309 computer boot rom. Developed during the Retro Challenge 2019/10.

The 4k ROM lives from 0xF000 to 0xFFFF in the HD6309 address space.

The source code is meant to be compiled with the LWASM assembler.

# Monitor commands

* M XXXX - show memory at HEX address XXXX.
* R XXXX - jump to HEX address XXXX and run.
