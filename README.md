# fmh_framebuffer
fmh_framebuffer is a framebuffer with an Avalon ST Video output.  As
such, It is compatible with the various components of the Intel 
Video and Image Processing Suite (VIP).
It is capable of flipping its output horizontally or vertically, the
combination of which can acheive 180 degree rotation.
It does not currently support 90 degree rotations.

It implements enough register level compatibility to be a
drop-in replacement for the old Intel (Altera) Frame Reader
when using the 
[altvipfb](https://github.com/fmhess/linux-socfpga/blob/socfpga-5.4.13-lts-fluke-cda/drivers/video/fbdev/altvipfb.c)
Linux driver.

## Status
It works.  It has been tested on a Cyclone V HPS system while
clocked at 60 MHz.  It was connected to RAM through a 64 bit
AXI bus, and its video output connected to a VIP Clocked Video Output
displaying 24 bit truecolor at 800x480 resolution.

The latest version of this core may be found
at <https://github.com/fmhess/fmh_framebuffer> .

## FAQ

* Q: Why did you bother?  The VIP suite already has framebuffer cores.
	* A: We needed a core capable of rotating its output by 180 degrees,
	  which is a capability the VIP framebuffers do not provide.
* Q: Okay then, why didn't you make a standalone rotator component instead
  of an integrated framebuffer/rotator?  The VIP suite is designed to
  consist of modular components which can be mixed and matched as
  the user desires.
	* A1: It is easier to write an integrated framebuffer/rotator than
	  a standalone rotator.  A framebuffer only needs to read RAM and
	  output a video stream.  A standalone rotator needs to do this
	  as well, and additionally needs to write RAM and receive an
	  input video stream.
	* A2: An integrated framebuffer/rotator is more efficient than
	  a standalone rotator.  The Avalon ST Video stream sends video
	  frames in a fixed order.  The rows of pixels are sent starting
	  from the top row and then working down.  Thus, in order to perform
	  a rotation or vertical flip a standalone rotator needs to
	  buffer an entire frame to the last row before it can begin sending 
	  the first row of the rotated output frame.  
	  
	  On the other hand, an integrated framebuffer/rotator gets its
	  input from RAM which it can read in any order.  Thus it can
	  begin output immediately and only needs to cache a single
	  row of the input frame at once in order to output a frame
	  which is vertically or horizontally flipped, or 180 degree
	  rotated.  90 degree rotations can be achieved efficiently
	  while only needing to cache a few columns at once of the input 
	  frame.

## Author
Frank Mori Hess fmh6jj@gmail.com
