MRV32: A Custom RV32 Computer System and Experimental Operating System

The MRV32 Platform is a complete, synthesizable RV32 computer system implemented in Verilog HDL, C, and 32-bit RISC-V assembly. It includes a custom RV32IM processor, memory, UART connectivity, SPI-based SD card storage, interrupt and trap handling, and a minimal operating system with a system calls and file descriptors-based kernel, a shell, and user programs. The system has been implemented and tested on the Digilent Basys 3 FPGA.
	
	MRV32 was conceived in the spirit of autodidactic learning, experimentation, and education for those interested in computer hardware design. It is an attempt at creating a whole, working system that runs (ported) third party software, implementing the RV32IM ISA. Rather than starting with a CPU and building software around it, the goal has been to design an integrated system, including the processor, memory, storage, and peripherals from the ground up. It is inspired by Ben Eater's Youtube Channel, David Marion (AKA FPGA Dude), digital ham radio, and "Digital Computer Electronics" by Albert Paul Malvino and Jerald Brown.


PLATFORM HARDWARE OVERVIEW

	The MRV32 hardware can be described as centrally controlled with a point-to-point datapath. Most of the control signals branch out from the centralized control module, with the remainder coming from the trap unit, which manages the direction to trap vectors in the event of syscalls and reception and transmission interrupts. The point to point nature of the modules' connectivity can be seen in the diagram. Please see the following Architecture sections for a more detailed description of the hardware and software architecture.
	
HOW TO CLONE THE REPO

Linux:

	Install git
	-----------
	Depending on your Linux distro, type in the name of the appropriate package manager, install git, and press enter in the terminal.
	For example (Ubuntu): sudo apt install git
		    (Fedora): sudo dnf install git
	
	Cloning the repo
	----------------
	1) Go to the Github repository in your browser
	2) Click the green Code button
	3) Copy the web URL
	4) Open a terminal, and cd to the directory where you would like to put the code
	5) type "git clone <repo URL>" and press enter
	
Windows:
	
	1) Install GitHub Desktop
	2) Open the program
	3) Go to File > Clone Repository
	4) Select the GitHub.com tab to search for your repositories, or use the URL tab to paste a specific link
	5) Choose Location: Click Choose... to select where the files should be saved on your Windows PC and click Clone
	
	
HOW TO BUILD THE PLATFORM (WITH INCLUDED OS AND USER PROGRAMS)

	Though the MRV32 Platform was designed for use on the Basys 3 FPGA in conjuction with the Digilent SD Card pmod, it can probably be built for other FPGAs too. That said, these instructions will assume that the Basys 3 is being used with Vivado.
	First, Vivado will need to be installed. It can be downloaded from the AMD website. Either Windows or Linux should do, though it has been tested on Linux. The version that is known to be good is 2025.2. If installing in Linux, the tar archive installation may be necessary.
	A serial terminal program will also be needed. Putty has been found to work well.
	Once Vivado is installed, start it and create a new project. In the project creation, upload the source (.v) files and the constraint (.xdc) file. If an FPGA other than the Basys 3 is being used, a different constraint file will have to be made up. If a new constraint file is being made up, it will need a clock, rx and tx UART pins, and sclk, mosi, miso, and cs for the sd card reader. Once the files are in Vivado and the project is created, the clock speed will have to be modified in order for the system to run on a Basys 3. Other FPGAs may not need this. The clock speed can be modified via the Clocking Wizard IP (intellectual property). In Vivado 2025.2, go to Window -> IP Catalog, and search for "clocking wizard". Set up the new clock in the wizard. An arbitrary working clock is 80 MHz for the Basys 3. It will be necessary to insert an instantiation of the clocking wizard that matches the newly generated clocking wizard module. It can be adjusted to be faster as long as the WNS (worst negative slack) and WHS (worst hold slack) are not negative and the UART timing counters and sd controller counters are adjusted. After the clocking wizard is set up, just generate the bitstream, wait for it to finish, open the hardware manager, connect to your device, open Putty for your serial device at 19200 baud (or whatever baud rate you have modified it to), and Program Device in Vivado. You should see the prompt in your Putty window.
	
	
HOW TO RUN THE OS

	As is, the OS is simple. It currently comes with two ported, third party user programs: TinyBasicLike and Kilo. TinyBasicLike is a Tiny Basic interpreter that can also be used to create new Tiny Basic programs. Kilo is a small text editor. Tiny Basic programs can be created either in TinyBasicLike or Kilo, though it is the author's opinion that for the purpose of greater editability, Kilo is more convenient. The .bas file created in Kilo can be run in TinyBasicLike. The licenses for the user programs are included in the repository.
	SD card block-level read and write functionality is currently operational through the MRV32 hardware and operating system. Higher-level storage functionality, including filesystem support, memory mapping, and directory viewing, remains under development. If SD card storage is desired, the sys_sd_read and sys_sd_write functions may be used to transfer data from the memory to the storage or vice-versus. Simply provide a pointer to the memory location and an SD card block number as the arguments to the syscall function.
	To run a program, simply type in its name. If you type something that does not match a directory table entry, the shell will print "INVALID COMMAND" and give you a new prompt. The exact, case sensitive names of the two programs are Basic and Kilo.

	
SUPPORTED AND TESTED DEVELOPMENT TOOLS

	So far, the only tested synthesis tool for the MRV32 Platform is Vivado. The reader is encouraged to try synthesizing the platform on other tools and letting the author know whether they work.
	Icarus Verilog and a UART testbench were used to simulate and troubleshoot the platform. The testbench has been included in the repository. It is useful for testing boot and user program startup functionality. It works by supplying a clock to the top system module, waiting a predetermined amount of time, and then triggering a UART transmission to be received by the device under test.
	There are a few steps to setting up the testbench, but it is not a long or tedious process. Instructions are as follows:
	
	-Comment out the clock wizard instantiation in the top module of the device under test, and set the clock inputs to have the same name as the clocks that are going into each module.
	-Decide what command you want to issue, and translate it into ASCII characters. Put the ASCII characters into the buffer in the initialization of the tbUART module inside the testbench file.
	-Insert a delay in the initialization of the top of the testbench that is long enough to get through the kernel boot/prompt process. 
	-After the delay, at the desired time of UART transmission, set tx_trig to 1. This will initiate the UART transmission process from testbench to soft-core. 
	-It is also necessary to include another delay after the tx_trig that is long enough to both transmit the UART command and watch an appropriate amount of debug info to investigate whatever you are trying to solve.
	
	In the top module, there is a reg called "indicators." Set this to "1" if it is desired to turn on selected debug info that the author has found helpful. 
	
	
A PATH TO DESIGNING YOUR OWN COMPUTER SYSTEM

	Designing a computer system can be a fun and rewarding challenge. The author feels that it is definitely within reach of most people that are willing to learn and have genuine interest in computers and how they work. There are really only two ingredients to getting started: knowing how the systems work and being able to code them. Here, a path will be presented to those interested in taking it on.
	The SAP (simple as possible) computers, presented in the book "Digital Computer Electronics" by Albert Malvino and Jerald Brown, are a good first step to learning about how computer processors and their surrounding systems work. These computers have a limited number of modules and relatively straight forward operation. SAP 1 can even be built on breadboards and programmed with switches. The book is written so that it is possible to understand the SAP computers without much extra reading. Buying a hard copy is encouraged.
	While learning the SAP computers, it is encouraged to start trying to code them in Verilog and simulate them. It won't be easy at first. Though Verilog's similarity to C makes it relatively intuitive, there will be obstacles in the beginning. It would be good to look up and work through some online tutorials first. Start simple and work your way up. Get a Verilog handbook. "Verilog HDL: A Guide to Digital Design and Synthesis" by Samir Palnitkar is a good one.
	The next level of coding in Verilog is synthesizability. Getting a Basys 3 or similar entry level FPGA and trying to run your Verilog on it is really the final hurdle to designing computers, and it is very satisfying. Getting the FPGA to cooperate can be a frustration, but it's a major victory when you succeed, and it really feels good. Also, once you know what works and what doesn't, the hardware bugs get fewer and farther between.
	

NOTES AND ACKNOWLEDGEMENTS

	The hardware system, OS, and user program source files have been included. With these files, the user should be able to simulate the system as is with the OS, modify either the hardware or the software, or add new or different user programs. It is hoped that the author's journey in producing this work will spark interest in FPGA work and OS development.
	The author was not the sole contributor to the porting of TinyBasicLike and Kilo. The user programs' licenses are included in the repository.
	The MIT license applies to both the platform's OS and hardware.
