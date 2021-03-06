![PS3_Glitch_Finder](https://raw.githubusercontent.com/modrobert/ps3_glitch_finder/master/ps3_glitch_finder_setup.jpg)
<pre>
              ____        ___ __      __     ____         __
    ___  ___ |_  /  ___ _/ (_) /_____/ /    / _(_)__  ___/ /__ ____
   / _ \(_-<_/_ <  / _ `/ / / __/ __/ _ \  / _/ / _ \/ _  / -_) __/
  / .__/___/____/  \_, /_/_/\__/\__/_//_/ /_//_/_//_/\_,_/\__/_/
 /_/              /___/          
_.-._.-._.-._.-._.-._.-._.-._.-._.-._.-._.-._.-._.-._.-._.-._.-._.-._.-._.-._
</pre>

PS3 Glitch Finder v1.0 by modrobert

Description:
============
This VHDL design for the Spartan-3 FPGA creates a custom pulse which can be 
used to glitch various hardware, like the PS3 memory bus. The pulse LOW and
HIGH multipliers have a resolution of 255 (X"FF") and can be set independently.

Features:
=========
* Cycle exaxt pulse generator process tested with logic analyzer
* Digital Clock Manager (DCM) primitive @ 200MHz (5ns) with lock handling
* Continuous pulse or one-shot mode selectable via switch
* Debounce handling for push buttons to prevent erratic behavior
* Set the LOW and HIGH pulse length multipliers via buttons
* 7-seg LED display support showing HIGH and LOW pulse multipliers
* Open source release under GPL v2

Operation:
==========
#### One-shot mode
![One-shot mode](https://raw.githubusercontent.com/modrobert/ps3_glitch_finder/master/ps3_glitch_finder_one_shot_pulse.jpg)
  
As seen on the image above the high pulse multiplier is set to X"64" (100 decimal x 5ns = 500ns = 0.5µs) and low pulse multiplier is at X"C8" (200 decimal x 5ns = 1000ns = 1µs), the lower part of the image is the pasted output from the logic analyzer to verify function. The device is set to one-shot pulse mode. The regular LED down on the right shows that the Digital Clock Manager is locked (at 200MHz / 5ns in this case).

#### Continuous mode 
![Continuous mode](https://raw.githubusercontent.com/modrobert/ps3_glitch_finder/master/ps3_glitch_finder_continous_pulse.jpg)
  
Here you can see the continuous mode in action, again, with high pulse multiplier set to X"64" (100 decimal x 5ns = 500ns = 0.5µs) and low pulse multiplier at X"C8" (200 decimal x 5ns = 1000ns = 1µs). The second LED down on the right indicates continuous mode is selected. 

Requirements:
=============
The target device is a Spartan-3 fitted on an FPGA board (eg. Spartan-3 Starter
Kit, Basys, Nexys, or similar). You need 5 push buttons (3 is ok also), a four 
digit "seven-segment" LED display, a dip switch, two regular LEDs, an external
crystal/clock at 25MHz or 50Mhz, and a free I/O port.

Notes:
======
This design is probably overkill for the purpose intended, but I had fun 
creating it, so one thing led to another. After the pulses are sent the
output port drives "Z" (instead if HIGH), thought that might be a good idea
to keep the PS3 linux kernel from crashing. I've only tested PS3 Glitch Finder
with a logic analyzer, not a scope yet, so the tri-state function has not been
properly tested. By driving the pulse low and switch to "Z" I did notice that
there can sometimes be roughly 300ns delay before high impedance occur, so to
prevent the pulse generator from sending an invalid long low pulse I made sure
the output is high before driving "Z". If you want to start out in the
footsteps of geohot, switch to one-shot mode and then set the low pulse
multiplier to 8 (8 x 5ns = 40ns) and the high can be 8 as well (don't think it
matter much since only one pulse is sent).

Greetings:
==========
Thank you geohot for the initial ps3 glich hack, and the fact you kept going
despite all the "professional doubters" out there. Hello xorloser, impressive
follow-up with software and hardware tools for us to play with.

