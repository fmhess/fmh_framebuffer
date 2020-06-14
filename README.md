# fmh_framebuffer
fmh_framebuffer is a framebuffer with an Avalon ST Video output.  As
such, It is compatible with the various components of the Intel 
Video and Image Processing Suite (VIP).
It is capable of flipping its output horizontally or vertically, the
combination of which can acheive 180 degree rotation.

It implements enough register level compatibility to be a
drop-in replacement for the old Intel (Altera) Frame Reader
when using the 
[altvipfb](https://github.com/fmhess/linux-socfpga/blob/socfpga-5.4.13-lts-fluke-cda/drivers/video/fbdev/altvipfb.c)
Linux driver.

## Status
It works.  It has been tested on a Cyclone V HPS system while
clocked at 60 MHz.  It was connected to RAM through a 64 bit
AXI bus.  Its video output sent 4 color channels of 8 bits
per color to a VIP Clocked Video Output
running at 800x480 resolution with a 60 Hz frame rate.

### Limitations
* All the colors of exactly one pixel are output in parallel on each
  beat of the video output stream.  So, no support for sending
  the colors of a single pixel sequentially over multiple output beats,
  and no support for sending multiple pixels in parallel on a
  single output beat.
* 90 degree rotations are not supported.
* Progressive frames only, no interlaced.

The latest version of this core may be found
at <https://github.com/fmhess/fmh_framebuffer> .

## FAQ

* Q: Why did you bother?  The VIP suite already has framebuffer cores.
	* A: We needed a core capable of rotating its output by 180 degrees,
	  which is a capability the VIP framebuffers do not provide.
* Q: Why didn't you make a dedicated rotator for VIP instead
  of an integrated framebuffer/rotator?  The VIP suite is designed to
  consist of modular components which can be mixed and matched as
  the user desires.
	* A1: It is easier to write an simple integrated framebuffer/rotator 
      than a pure rotator.  A framebuffer only needs to read RAM and
	  output a video stream.  A pure rotator needs to do this
	  as well, and additionally needs to write RAM and receive an
	  input video stream.
	* A2: An integrated framebuffer/rotator is more efficient than
	  a pure VIP rotator.  The Avalon ST Video stream sends video
	  frames in a prescribed order.  The rows of pixels are sent starting
	  from the top row and then working down.  Thus, in order to perform
	  a rotation or vertical flip, a pure VIP rotator needs to
	  buffer an entire frame in RAM down to the last row before 
	  it can begin sending the first row of the rotated output frame.  
	  
	  On the other hand, an integrated framebuffer/rotator gets its
	  input from RAM which it can read in any order.  Thus it only 
	  needs to cache a single
	  row of the input frame at once in order to output a frame
	  which is vertically or horizontally flipped, or 180 degree
	  rotated.  90 degree rotations can be achieved efficiently
	  while only needing to cache a few columns of the input 
	  frame at once.

## Author
Frank Mori Hess fmh6jj@gmail.com
