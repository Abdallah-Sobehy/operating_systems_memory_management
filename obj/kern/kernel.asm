
obj/kern/kernel:     file format elf32-i386


Disassembly of section .text:

f0100000 <_start+0xeffffff4>:
.globl		_start
_start = RELOC(entry)

.globl entry
entry:
	movw	$0x1234,0x472			# warm boot
f0100000:	02 b0 ad 1b 00 00    	add    0x1bad(%eax),%dh
f0100006:	00 00                	add    %al,(%eax)
f0100008:	fe 4f 52             	decb   0x52(%edi)
f010000b:	e4 66                	in     $0x66,%al

f010000c <entry>:
f010000c:	66 c7 05 72 04 00 00 	movw   $0x1234,0x472
f0100013:	34 12 
	# sufficient until we set up our real page table in mem_init
	# in lab 2.

	# Load the physical address of entry_pgdir into cr3.  entry_pgdir
	# is defined in entrypgdir.c.
	movl	$(RELOC(entry_pgdir)), %eax
f0100015:	b8 00 00 11 00       	mov    $0x110000,%eax
	movl	%eax, %cr3
f010001a:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl	%cr0, %eax
f010001d:	0f 20 c0             	mov    %cr0,%eax
	orl	$(CR0_PE|CR0_PG|CR0_WP), %eax
f0100020:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl	%eax, %cr0
f0100025:	0f 22 c0             	mov    %eax,%cr0

	# Now paging is enabled, but we're still running at a low EIP
	# (why is this okay?).  Jump up above KERNBASE before entering
	# C code.
	mov	$relocated, %eax
f0100028:	b8 2f 00 10 f0       	mov    $0xf010002f,%eax
	jmp	*%eax
f010002d:	ff e0                	jmp    *%eax

f010002f <relocated>:
relocated:

	# Clear the frame pointer register (EBP)
	# so that once we get into debugging C code,
	# stack backtraces will be terminated properly.
	movl	$0x0,%ebp			# nuke frame pointer
f010002f:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Set the stack pointer
	movl	$(bootstacktop),%esp
f0100034:	bc 00 00 11 f0       	mov    $0xf0110000,%esp

	# now to C code
	call	i386_init
f0100039:	e8 02 00 00 00       	call   f0100040 <i386_init>

f010003e <spin>:

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin
f010003e:	eb fe                	jmp    f010003e <spin>

f0100040 <i386_init>:
#include <kern/kclock.h>


void
i386_init(void)
{
f0100040:	55                   	push   %ebp
f0100041:	89 e5                	mov    %esp,%ebp
f0100043:	83 ec 18             	sub    $0x18,%esp
	extern char edata[], end[];

	// Before doing anything else, complete the ELF loading process.
	// Clear the uninitialized global data (BSS) section of our program.
	// This ensures that all static/global variables start out zero.
	memset(edata, 0, end - edata);
f0100046:	b8 70 29 11 f0       	mov    $0xf0112970,%eax
f010004b:	2d 00 23 11 f0       	sub    $0xf0112300,%eax
f0100050:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100054:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010005b:	00 
f010005c:	c7 04 24 00 23 11 f0 	movl   $0xf0112300,(%esp)
f0100063:	e8 7f 15 00 00       	call   f01015e7 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f0100068:	e8 a2 04 00 00       	call   f010050f <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f010006d:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f0100074:	00 
f0100075:	c7 04 24 80 1a 10 f0 	movl   $0xf0101a80,(%esp)
f010007c:	e8 68 0a 00 00       	call   f0100ae9 <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f0100081:	e8 30 08 00 00       	call   f01008b6 <mem_init>

	// Drop into the kernel monitor.
	while (1)
		monitor(NULL);
f0100086:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010008d:	e8 b7 06 00 00       	call   f0100749 <monitor>
f0100092:	eb f2                	jmp    f0100086 <i386_init+0x46>

f0100094 <_panic>:
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
void
_panic(const char *file, int line, const char *fmt,...)
{
f0100094:	55                   	push   %ebp
f0100095:	89 e5                	mov    %esp,%ebp
f0100097:	56                   	push   %esi
f0100098:	53                   	push   %ebx
f0100099:	83 ec 10             	sub    $0x10,%esp
f010009c:	8b 75 10             	mov    0x10(%ebp),%esi
	va_list ap;

	if (panicstr)
f010009f:	83 3d 60 29 11 f0 00 	cmpl   $0x0,0xf0112960
f01000a6:	75 3d                	jne    f01000e5 <_panic+0x51>
		goto dead;
	panicstr = fmt;
f01000a8:	89 35 60 29 11 f0    	mov    %esi,0xf0112960

	// Be extra sure that the machine is in as reasonable state
	asm volatile("cli; cld");
f01000ae:	fa                   	cli    
f01000af:	fc                   	cld    

	va_start(ap, fmt);
f01000b0:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic at %s:%d: ", file, line);
f01000b3:	8b 45 0c             	mov    0xc(%ebp),%eax
f01000b6:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000ba:	8b 45 08             	mov    0x8(%ebp),%eax
f01000bd:	89 44 24 04          	mov    %eax,0x4(%esp)
f01000c1:	c7 04 24 9b 1a 10 f0 	movl   $0xf0101a9b,(%esp)
f01000c8:	e8 1c 0a 00 00       	call   f0100ae9 <cprintf>
	vcprintf(fmt, ap);
f01000cd:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01000d1:	89 34 24             	mov    %esi,(%esp)
f01000d4:	e8 dd 09 00 00       	call   f0100ab6 <vcprintf>
	cprintf("\n");
f01000d9:	c7 04 24 d7 1a 10 f0 	movl   $0xf0101ad7,(%esp)
f01000e0:	e8 04 0a 00 00       	call   f0100ae9 <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f01000e5:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01000ec:	e8 58 06 00 00       	call   f0100749 <monitor>
f01000f1:	eb f2                	jmp    f01000e5 <_panic+0x51>

f01000f3 <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f01000f3:	55                   	push   %ebp
f01000f4:	89 e5                	mov    %esp,%ebp
f01000f6:	53                   	push   %ebx
f01000f7:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f01000fa:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f01000fd:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100100:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100104:	8b 45 08             	mov    0x8(%ebp),%eax
f0100107:	89 44 24 04          	mov    %eax,0x4(%esp)
f010010b:	c7 04 24 b3 1a 10 f0 	movl   $0xf0101ab3,(%esp)
f0100112:	e8 d2 09 00 00       	call   f0100ae9 <cprintf>
	vcprintf(fmt, ap);
f0100117:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010011b:	8b 45 10             	mov    0x10(%ebp),%eax
f010011e:	89 04 24             	mov    %eax,(%esp)
f0100121:	e8 90 09 00 00       	call   f0100ab6 <vcprintf>
	cprintf("\n");
f0100126:	c7 04 24 d7 1a 10 f0 	movl   $0xf0101ad7,(%esp)
f010012d:	e8 b7 09 00 00       	call   f0100ae9 <cprintf>
	va_end(ap);
}
f0100132:	83 c4 14             	add    $0x14,%esp
f0100135:	5b                   	pop    %ebx
f0100136:	5d                   	pop    %ebp
f0100137:	c3                   	ret    
f0100138:	66 90                	xchg   %ax,%ax
f010013a:	66 90                	xchg   %ax,%ax
f010013c:	66 90                	xchg   %ax,%ax
f010013e:	66 90                	xchg   %ax,%ax

f0100140 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f0100140:	55                   	push   %ebp
f0100141:	89 e5                	mov    %esp,%ebp

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100143:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100148:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f0100149:	a8 01                	test   $0x1,%al
f010014b:	74 08                	je     f0100155 <serial_proc_data+0x15>
f010014d:	b2 f8                	mov    $0xf8,%dl
f010014f:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f0100150:	0f b6 c0             	movzbl %al,%eax
f0100153:	eb 05                	jmp    f010015a <serial_proc_data+0x1a>

static int
serial_proc_data(void)
{
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
		return -1;
f0100155:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	return inb(COM1+COM_RX);
}
f010015a:	5d                   	pop    %ebp
f010015b:	c3                   	ret    

f010015c <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f010015c:	55                   	push   %ebp
f010015d:	89 e5                	mov    %esp,%ebp
f010015f:	53                   	push   %ebx
f0100160:	83 ec 04             	sub    $0x4,%esp
f0100163:	89 c3                	mov    %eax,%ebx
	int c;

	while ((c = (*proc)()) != -1) {
f0100165:	eb 2a                	jmp    f0100191 <cons_intr+0x35>
		if (c == 0)
f0100167:	85 d2                	test   %edx,%edx
f0100169:	74 26                	je     f0100191 <cons_intr+0x35>
			continue;
		cons.buf[cons.wpos++] = c;
f010016b:	a1 24 25 11 f0       	mov    0xf0112524,%eax
f0100170:	8d 48 01             	lea    0x1(%eax),%ecx
f0100173:	89 0d 24 25 11 f0    	mov    %ecx,0xf0112524
f0100179:	88 90 20 23 11 f0    	mov    %dl,-0xfeedce0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f010017f:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f0100185:	75 0a                	jne    f0100191 <cons_intr+0x35>
			cons.wpos = 0;
f0100187:	c7 05 24 25 11 f0 00 	movl   $0x0,0xf0112524
f010018e:	00 00 00 
static void
cons_intr(int (*proc)(void))
{
	int c;

	while ((c = (*proc)()) != -1) {
f0100191:	ff d3                	call   *%ebx
f0100193:	89 c2                	mov    %eax,%edx
f0100195:	83 f8 ff             	cmp    $0xffffffff,%eax
f0100198:	75 cd                	jne    f0100167 <cons_intr+0xb>
			continue;
		cons.buf[cons.wpos++] = c;
		if (cons.wpos == CONSBUFSIZE)
			cons.wpos = 0;
	}
}
f010019a:	83 c4 04             	add    $0x4,%esp
f010019d:	5b                   	pop    %ebx
f010019e:	5d                   	pop    %ebp
f010019f:	c3                   	ret    

f01001a0 <kbd_proc_data>:
f01001a0:	ba 64 00 00 00       	mov    $0x64,%edx
f01001a5:	ec                   	in     (%dx),%al
	int c;
	uint8_t stat, data;
	static uint32_t shift;

	stat = inb(KBSTATP);
	if ((stat & KBS_DIB) == 0)
f01001a6:	a8 01                	test   $0x1,%al
f01001a8:	0f 84 f7 00 00 00    	je     f01002a5 <kbd_proc_data+0x105>
		return -1;
	// Ignore data from mouse.
	if (stat & KBS_TERR)
f01001ae:	a8 20                	test   $0x20,%al
f01001b0:	0f 85 f5 00 00 00    	jne    f01002ab <kbd_proc_data+0x10b>
f01001b6:	b2 60                	mov    $0x60,%dl
f01001b8:	ec                   	in     (%dx),%al
f01001b9:	89 c2                	mov    %eax,%edx
		return -1;

	data = inb(KBDATAP);

	if (data == 0xE0) {
f01001bb:	3c e0                	cmp    $0xe0,%al
f01001bd:	75 0d                	jne    f01001cc <kbd_proc_data+0x2c>
		// E0 escape character
		shift |= E0ESC;
f01001bf:	83 0d 00 23 11 f0 40 	orl    $0x40,0xf0112300
		return 0;
f01001c6:	b8 00 00 00 00       	mov    $0x0,%eax
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f01001cb:	c3                   	ret    
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int
kbd_proc_data(void)
{
f01001cc:	55                   	push   %ebp
f01001cd:	89 e5                	mov    %esp,%ebp
f01001cf:	53                   	push   %ebx
f01001d0:	83 ec 14             	sub    $0x14,%esp

	if (data == 0xE0) {
		// E0 escape character
		shift |= E0ESC;
		return 0;
	} else if (data & 0x80) {
f01001d3:	84 c0                	test   %al,%al
f01001d5:	79 37                	jns    f010020e <kbd_proc_data+0x6e>
		// Key released
		data = (shift & E0ESC ? data : data & 0x7F);
f01001d7:	8b 0d 00 23 11 f0    	mov    0xf0112300,%ecx
f01001dd:	89 cb                	mov    %ecx,%ebx
f01001df:	83 e3 40             	and    $0x40,%ebx
f01001e2:	83 e0 7f             	and    $0x7f,%eax
f01001e5:	85 db                	test   %ebx,%ebx
f01001e7:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f01001ea:	0f b6 d2             	movzbl %dl,%edx
f01001ed:	0f b6 82 20 1c 10 f0 	movzbl -0xfefe3e0(%edx),%eax
f01001f4:	83 c8 40             	or     $0x40,%eax
f01001f7:	0f b6 c0             	movzbl %al,%eax
f01001fa:	f7 d0                	not    %eax
f01001fc:	21 c1                	and    %eax,%ecx
f01001fe:	89 0d 00 23 11 f0    	mov    %ecx,0xf0112300
		return 0;
f0100204:	b8 00 00 00 00       	mov    $0x0,%eax
f0100209:	e9 a3 00 00 00       	jmp    f01002b1 <kbd_proc_data+0x111>
	} else if (shift & E0ESC) {
f010020e:	8b 0d 00 23 11 f0    	mov    0xf0112300,%ecx
f0100214:	f6 c1 40             	test   $0x40,%cl
f0100217:	74 0e                	je     f0100227 <kbd_proc_data+0x87>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f0100219:	83 c8 80             	or     $0xffffff80,%eax
f010021c:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f010021e:	83 e1 bf             	and    $0xffffffbf,%ecx
f0100221:	89 0d 00 23 11 f0    	mov    %ecx,0xf0112300
	}

	shift |= shiftcode[data];
f0100227:	0f b6 d2             	movzbl %dl,%edx
f010022a:	0f b6 82 20 1c 10 f0 	movzbl -0xfefe3e0(%edx),%eax
f0100231:	0b 05 00 23 11 f0    	or     0xf0112300,%eax
	shift ^= togglecode[data];
f0100237:	0f b6 8a 20 1b 10 f0 	movzbl -0xfefe4e0(%edx),%ecx
f010023e:	31 c8                	xor    %ecx,%eax
f0100240:	a3 00 23 11 f0       	mov    %eax,0xf0112300

	c = charcode[shift & (CTL | SHIFT)][data];
f0100245:	89 c1                	mov    %eax,%ecx
f0100247:	83 e1 03             	and    $0x3,%ecx
f010024a:	8b 0c 8d 00 1b 10 f0 	mov    -0xfefe500(,%ecx,4),%ecx
f0100251:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f0100255:	0f b6 da             	movzbl %dl,%ebx
	if (shift & CAPSLOCK) {
f0100258:	a8 08                	test   $0x8,%al
f010025a:	74 1b                	je     f0100277 <kbd_proc_data+0xd7>
		if ('a' <= c && c <= 'z')
f010025c:	89 da                	mov    %ebx,%edx
f010025e:	8d 4b 9f             	lea    -0x61(%ebx),%ecx
f0100261:	83 f9 19             	cmp    $0x19,%ecx
f0100264:	77 05                	ja     f010026b <kbd_proc_data+0xcb>
			c += 'A' - 'a';
f0100266:	83 eb 20             	sub    $0x20,%ebx
f0100269:	eb 0c                	jmp    f0100277 <kbd_proc_data+0xd7>
		else if ('A' <= c && c <= 'Z')
f010026b:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f010026e:	8d 4b 20             	lea    0x20(%ebx),%ecx
f0100271:	83 fa 19             	cmp    $0x19,%edx
f0100274:	0f 46 d9             	cmovbe %ecx,%ebx
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f0100277:	f7 d0                	not    %eax
f0100279:	89 c2                	mov    %eax,%edx
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f010027b:	89 d8                	mov    %ebx,%eax
			c += 'a' - 'A';
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f010027d:	f6 c2 06             	test   $0x6,%dl
f0100280:	75 2f                	jne    f01002b1 <kbd_proc_data+0x111>
f0100282:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f0100288:	75 27                	jne    f01002b1 <kbd_proc_data+0x111>
		cprintf("Rebooting!\n");
f010028a:	c7 04 24 cd 1a 10 f0 	movl   $0xf0101acd,(%esp)
f0100291:	e8 53 08 00 00       	call   f0100ae9 <cprintf>
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100296:	ba 92 00 00 00       	mov    $0x92,%edx
f010029b:	b8 03 00 00 00       	mov    $0x3,%eax
f01002a0:	ee                   	out    %al,(%dx)
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f01002a1:	89 d8                	mov    %ebx,%eax
f01002a3:	eb 0c                	jmp    f01002b1 <kbd_proc_data+0x111>
	uint8_t stat, data;
	static uint32_t shift;

	stat = inb(KBSTATP);
	if ((stat & KBS_DIB) == 0)
		return -1;
f01002a5:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01002aa:	c3                   	ret    
	// Ignore data from mouse.
	if (stat & KBS_TERR)
		return -1;
f01002ab:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01002b0:	c3                   	ret    
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f01002b1:	83 c4 14             	add    $0x14,%esp
f01002b4:	5b                   	pop    %ebx
f01002b5:	5d                   	pop    %ebp
f01002b6:	c3                   	ret    

f01002b7 <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f01002b7:	55                   	push   %ebp
f01002b8:	89 e5                	mov    %esp,%ebp
f01002ba:	57                   	push   %edi
f01002bb:	56                   	push   %esi
f01002bc:	53                   	push   %ebx
f01002bd:	83 ec 1c             	sub    $0x1c,%esp
f01002c0:	89 c7                	mov    %eax,%edi
f01002c2:	bb 01 32 00 00       	mov    $0x3201,%ebx

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01002c7:	be fd 03 00 00       	mov    $0x3fd,%esi
f01002cc:	b9 84 00 00 00       	mov    $0x84,%ecx
f01002d1:	eb 06                	jmp    f01002d9 <cons_putc+0x22>
f01002d3:	89 ca                	mov    %ecx,%edx
f01002d5:	ec                   	in     (%dx),%al
f01002d6:	ec                   	in     (%dx),%al
f01002d7:	ec                   	in     (%dx),%al
f01002d8:	ec                   	in     (%dx),%al
f01002d9:	89 f2                	mov    %esi,%edx
f01002db:	ec                   	in     (%dx),%al
static void
serial_putc(int c)
{
	int i;

	for (i = 0;
f01002dc:	a8 20                	test   $0x20,%al
f01002de:	75 05                	jne    f01002e5 <cons_putc+0x2e>
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f01002e0:	83 eb 01             	sub    $0x1,%ebx
f01002e3:	75 ee                	jne    f01002d3 <cons_putc+0x1c>
	     i++)
		delay();

	outb(COM1 + COM_TX, c);
f01002e5:	89 f8                	mov    %edi,%eax
f01002e7:	0f b6 c0             	movzbl %al,%eax
f01002ea:	89 45 e4             	mov    %eax,-0x1c(%ebp)
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01002ed:	ba f8 03 00 00       	mov    $0x3f8,%edx
f01002f2:	ee                   	out    %al,(%dx)
f01002f3:	bb 01 32 00 00       	mov    $0x3201,%ebx

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01002f8:	be 79 03 00 00       	mov    $0x379,%esi
f01002fd:	b9 84 00 00 00       	mov    $0x84,%ecx
f0100302:	eb 06                	jmp    f010030a <cons_putc+0x53>
f0100304:	89 ca                	mov    %ecx,%edx
f0100306:	ec                   	in     (%dx),%al
f0100307:	ec                   	in     (%dx),%al
f0100308:	ec                   	in     (%dx),%al
f0100309:	ec                   	in     (%dx),%al
f010030a:	89 f2                	mov    %esi,%edx
f010030c:	ec                   	in     (%dx),%al
static void
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f010030d:	84 c0                	test   %al,%al
f010030f:	78 05                	js     f0100316 <cons_putc+0x5f>
f0100311:	83 eb 01             	sub    $0x1,%ebx
f0100314:	75 ee                	jne    f0100304 <cons_putc+0x4d>
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100316:	ba 78 03 00 00       	mov    $0x378,%edx
f010031b:	0f b6 45 e4          	movzbl -0x1c(%ebp),%eax
f010031f:	ee                   	out    %al,(%dx)
f0100320:	b2 7a                	mov    $0x7a,%dl
f0100322:	b8 0d 00 00 00       	mov    $0xd,%eax
f0100327:	ee                   	out    %al,(%dx)
f0100328:	b8 08 00 00 00       	mov    $0x8,%eax
f010032d:	ee                   	out    %al,(%dx)

static void
cga_putc(int c)
{
	// if no attribute given, then use black on white
	if (!(c & ~0xFF))
f010032e:	89 fa                	mov    %edi,%edx
f0100330:	81 e2 00 ff ff ff    	and    $0xffffff00,%edx
		c |= 0x0700;
f0100336:	89 f8                	mov    %edi,%eax
f0100338:	80 cc 07             	or     $0x7,%ah
f010033b:	85 d2                	test   %edx,%edx
f010033d:	0f 44 f8             	cmove  %eax,%edi

	switch (c & 0xff) {
f0100340:	89 f8                	mov    %edi,%eax
f0100342:	0f b6 c0             	movzbl %al,%eax
f0100345:	83 f8 09             	cmp    $0x9,%eax
f0100348:	74 78                	je     f01003c2 <cons_putc+0x10b>
f010034a:	83 f8 09             	cmp    $0x9,%eax
f010034d:	7f 0a                	jg     f0100359 <cons_putc+0xa2>
f010034f:	83 f8 08             	cmp    $0x8,%eax
f0100352:	74 18                	je     f010036c <cons_putc+0xb5>
f0100354:	e9 9d 00 00 00       	jmp    f01003f6 <cons_putc+0x13f>
f0100359:	83 f8 0a             	cmp    $0xa,%eax
f010035c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100360:	74 3a                	je     f010039c <cons_putc+0xe5>
f0100362:	83 f8 0d             	cmp    $0xd,%eax
f0100365:	74 3d                	je     f01003a4 <cons_putc+0xed>
f0100367:	e9 8a 00 00 00       	jmp    f01003f6 <cons_putc+0x13f>
	case '\b':
		if (crt_pos > 0) {
f010036c:	0f b7 05 28 25 11 f0 	movzwl 0xf0112528,%eax
f0100373:	66 85 c0             	test   %ax,%ax
f0100376:	0f 84 e5 00 00 00    	je     f0100461 <cons_putc+0x1aa>
			crt_pos--;
f010037c:	83 e8 01             	sub    $0x1,%eax
f010037f:	66 a3 28 25 11 f0    	mov    %ax,0xf0112528
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100385:	0f b7 c0             	movzwl %ax,%eax
f0100388:	66 81 e7 00 ff       	and    $0xff00,%di
f010038d:	83 cf 20             	or     $0x20,%edi
f0100390:	8b 15 2c 25 11 f0    	mov    0xf011252c,%edx
f0100396:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f010039a:	eb 78                	jmp    f0100414 <cons_putc+0x15d>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f010039c:	66 83 05 28 25 11 f0 	addw   $0x50,0xf0112528
f01003a3:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f01003a4:	0f b7 05 28 25 11 f0 	movzwl 0xf0112528,%eax
f01003ab:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f01003b1:	c1 e8 16             	shr    $0x16,%eax
f01003b4:	8d 04 80             	lea    (%eax,%eax,4),%eax
f01003b7:	c1 e0 04             	shl    $0x4,%eax
f01003ba:	66 a3 28 25 11 f0    	mov    %ax,0xf0112528
f01003c0:	eb 52                	jmp    f0100414 <cons_putc+0x15d>
		break;
	case '\t':
		cons_putc(' ');
f01003c2:	b8 20 00 00 00       	mov    $0x20,%eax
f01003c7:	e8 eb fe ff ff       	call   f01002b7 <cons_putc>
		cons_putc(' ');
f01003cc:	b8 20 00 00 00       	mov    $0x20,%eax
f01003d1:	e8 e1 fe ff ff       	call   f01002b7 <cons_putc>
		cons_putc(' ');
f01003d6:	b8 20 00 00 00       	mov    $0x20,%eax
f01003db:	e8 d7 fe ff ff       	call   f01002b7 <cons_putc>
		cons_putc(' ');
f01003e0:	b8 20 00 00 00       	mov    $0x20,%eax
f01003e5:	e8 cd fe ff ff       	call   f01002b7 <cons_putc>
		cons_putc(' ');
f01003ea:	b8 20 00 00 00       	mov    $0x20,%eax
f01003ef:	e8 c3 fe ff ff       	call   f01002b7 <cons_putc>
f01003f4:	eb 1e                	jmp    f0100414 <cons_putc+0x15d>
		break;
	default:
		crt_buf[crt_pos++] = c;		/* write the character */
f01003f6:	0f b7 05 28 25 11 f0 	movzwl 0xf0112528,%eax
f01003fd:	8d 50 01             	lea    0x1(%eax),%edx
f0100400:	66 89 15 28 25 11 f0 	mov    %dx,0xf0112528
f0100407:	0f b7 c0             	movzwl %ax,%eax
f010040a:	8b 15 2c 25 11 f0    	mov    0xf011252c,%edx
f0100410:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f0100414:	66 81 3d 28 25 11 f0 	cmpw   $0x7cf,0xf0112528
f010041b:	cf 07 
f010041d:	76 42                	jbe    f0100461 <cons_putc+0x1aa>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f010041f:	a1 2c 25 11 f0       	mov    0xf011252c,%eax
f0100424:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f010042b:	00 
f010042c:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100432:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100436:	89 04 24             	mov    %eax,(%esp)
f0100439:	e8 f6 11 00 00       	call   f0101634 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f010043e:	8b 15 2c 25 11 f0    	mov    0xf011252c,%edx
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f0100444:	b8 80 07 00 00       	mov    $0x780,%eax
			crt_buf[i] = 0x0700 | ' ';
f0100449:	66 c7 04 42 20 07    	movw   $0x720,(%edx,%eax,2)
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f010044f:	83 c0 01             	add    $0x1,%eax
f0100452:	3d d0 07 00 00       	cmp    $0x7d0,%eax
f0100457:	75 f0                	jne    f0100449 <cons_putc+0x192>
			crt_buf[i] = 0x0700 | ' ';
		crt_pos -= CRT_COLS;
f0100459:	66 83 2d 28 25 11 f0 	subw   $0x50,0xf0112528
f0100460:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100461:	8b 0d 30 25 11 f0    	mov    0xf0112530,%ecx
f0100467:	b8 0e 00 00 00       	mov    $0xe,%eax
f010046c:	89 ca                	mov    %ecx,%edx
f010046e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010046f:	0f b7 1d 28 25 11 f0 	movzwl 0xf0112528,%ebx
f0100476:	8d 71 01             	lea    0x1(%ecx),%esi
f0100479:	89 d8                	mov    %ebx,%eax
f010047b:	66 c1 e8 08          	shr    $0x8,%ax
f010047f:	89 f2                	mov    %esi,%edx
f0100481:	ee                   	out    %al,(%dx)
f0100482:	b8 0f 00 00 00       	mov    $0xf,%eax
f0100487:	89 ca                	mov    %ecx,%edx
f0100489:	ee                   	out    %al,(%dx)
f010048a:	89 d8                	mov    %ebx,%eax
f010048c:	89 f2                	mov    %esi,%edx
f010048e:	ee                   	out    %al,(%dx)
cons_putc(int c)
{
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f010048f:	83 c4 1c             	add    $0x1c,%esp
f0100492:	5b                   	pop    %ebx
f0100493:	5e                   	pop    %esi
f0100494:	5f                   	pop    %edi
f0100495:	5d                   	pop    %ebp
f0100496:	c3                   	ret    

f0100497 <serial_intr>:
}

void
serial_intr(void)
{
	if (serial_exists)
f0100497:	80 3d 34 25 11 f0 00 	cmpb   $0x0,0xf0112534
f010049e:	74 11                	je     f01004b1 <serial_intr+0x1a>
	return inb(COM1+COM_RX);
}

void
serial_intr(void)
{
f01004a0:	55                   	push   %ebp
f01004a1:	89 e5                	mov    %esp,%ebp
f01004a3:	83 ec 08             	sub    $0x8,%esp
	if (serial_exists)
		cons_intr(serial_proc_data);
f01004a6:	b8 40 01 10 f0       	mov    $0xf0100140,%eax
f01004ab:	e8 ac fc ff ff       	call   f010015c <cons_intr>
}
f01004b0:	c9                   	leave  
f01004b1:	f3 c3                	repz ret 

f01004b3 <kbd_intr>:
	return c;
}

void
kbd_intr(void)
{
f01004b3:	55                   	push   %ebp
f01004b4:	89 e5                	mov    %esp,%ebp
f01004b6:	83 ec 08             	sub    $0x8,%esp
	cons_intr(kbd_proc_data);
f01004b9:	b8 a0 01 10 f0       	mov    $0xf01001a0,%eax
f01004be:	e8 99 fc ff ff       	call   f010015c <cons_intr>
}
f01004c3:	c9                   	leave  
f01004c4:	c3                   	ret    

f01004c5 <cons_getc>:
}

// return the next input character from the console, or 0 if none waiting
int
cons_getc(void)
{
f01004c5:	55                   	push   %ebp
f01004c6:	89 e5                	mov    %esp,%ebp
f01004c8:	83 ec 08             	sub    $0x8,%esp
	int c;

	// poll for any pending input characters,
	// so that this function works even when interrupts are disabled
	// (e.g., when called from the kernel monitor).
	serial_intr();
f01004cb:	e8 c7 ff ff ff       	call   f0100497 <serial_intr>
	kbd_intr();
f01004d0:	e8 de ff ff ff       	call   f01004b3 <kbd_intr>

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
f01004d5:	a1 20 25 11 f0       	mov    0xf0112520,%eax
f01004da:	3b 05 24 25 11 f0    	cmp    0xf0112524,%eax
f01004e0:	74 26                	je     f0100508 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f01004e2:	8d 50 01             	lea    0x1(%eax),%edx
f01004e5:	89 15 20 25 11 f0    	mov    %edx,0xf0112520
f01004eb:	0f b6 88 20 23 11 f0 	movzbl -0xfeedce0(%eax),%ecx
		if (cons.rpos == CONSBUFSIZE)
			cons.rpos = 0;
		return c;
f01004f2:	89 c8                	mov    %ecx,%eax
	kbd_intr();

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
		c = cons.buf[cons.rpos++];
		if (cons.rpos == CONSBUFSIZE)
f01004f4:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f01004fa:	75 11                	jne    f010050d <cons_getc+0x48>
			cons.rpos = 0;
f01004fc:	c7 05 20 25 11 f0 00 	movl   $0x0,0xf0112520
f0100503:	00 00 00 
f0100506:	eb 05                	jmp    f010050d <cons_getc+0x48>
		return c;
	}
	return 0;
f0100508:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010050d:	c9                   	leave  
f010050e:	c3                   	ret    

f010050f <cons_init>:
}

// initialize the console devices
void
cons_init(void)
{
f010050f:	55                   	push   %ebp
f0100510:	89 e5                	mov    %esp,%ebp
f0100512:	57                   	push   %edi
f0100513:	56                   	push   %esi
f0100514:	53                   	push   %ebx
f0100515:	83 ec 1c             	sub    $0x1c,%esp
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
f0100518:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f010051f:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f0100526:	5a a5 
	if (*cp != 0xA55A) {
f0100528:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f010052f:	66 3d 5a a5          	cmp    $0xa55a,%ax
f0100533:	74 11                	je     f0100546 <cons_init+0x37>
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
		addr_6845 = MONO_BASE;
f0100535:	c7 05 30 25 11 f0 b4 	movl   $0x3b4,0xf0112530
f010053c:	03 00 00 

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
	*cp = (uint16_t) 0xA55A;
	if (*cp != 0xA55A) {
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f010053f:	bf 00 00 0b f0       	mov    $0xf00b0000,%edi
f0100544:	eb 16                	jmp    f010055c <cons_init+0x4d>
		addr_6845 = MONO_BASE;
	} else {
		*cp = was;
f0100546:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f010054d:	c7 05 30 25 11 f0 d4 	movl   $0x3d4,0xf0112530
f0100554:	03 00 00 
{
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f0100557:	bf 00 80 0b f0       	mov    $0xf00b8000,%edi
		*cp = was;
		addr_6845 = CGA_BASE;
	}

	/* Extract cursor location */
	outb(addr_6845, 14);
f010055c:	8b 0d 30 25 11 f0    	mov    0xf0112530,%ecx
f0100562:	b8 0e 00 00 00       	mov    $0xe,%eax
f0100567:	89 ca                	mov    %ecx,%edx
f0100569:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f010056a:	8d 59 01             	lea    0x1(%ecx),%ebx

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010056d:	89 da                	mov    %ebx,%edx
f010056f:	ec                   	in     (%dx),%al
f0100570:	0f b6 f0             	movzbl %al,%esi
f0100573:	c1 e6 08             	shl    $0x8,%esi
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100576:	b8 0f 00 00 00       	mov    $0xf,%eax
f010057b:	89 ca                	mov    %ecx,%edx
f010057d:	ee                   	out    %al,(%dx)

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010057e:	89 da                	mov    %ebx,%edx
f0100580:	ec                   	in     (%dx),%al
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);

	crt_buf = (uint16_t*) cp;
f0100581:	89 3d 2c 25 11 f0    	mov    %edi,0xf011252c

	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f0100587:	0f b6 d8             	movzbl %al,%ebx
f010058a:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f010058c:	66 89 35 28 25 11 f0 	mov    %si,0xf0112528
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100593:	be fa 03 00 00       	mov    $0x3fa,%esi
f0100598:	b8 00 00 00 00       	mov    $0x0,%eax
f010059d:	89 f2                	mov    %esi,%edx
f010059f:	ee                   	out    %al,(%dx)
f01005a0:	b2 fb                	mov    $0xfb,%dl
f01005a2:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f01005a7:	ee                   	out    %al,(%dx)
f01005a8:	bb f8 03 00 00       	mov    $0x3f8,%ebx
f01005ad:	b8 0c 00 00 00       	mov    $0xc,%eax
f01005b2:	89 da                	mov    %ebx,%edx
f01005b4:	ee                   	out    %al,(%dx)
f01005b5:	b2 f9                	mov    $0xf9,%dl
f01005b7:	b8 00 00 00 00       	mov    $0x0,%eax
f01005bc:	ee                   	out    %al,(%dx)
f01005bd:	b2 fb                	mov    $0xfb,%dl
f01005bf:	b8 03 00 00 00       	mov    $0x3,%eax
f01005c4:	ee                   	out    %al,(%dx)
f01005c5:	b2 fc                	mov    $0xfc,%dl
f01005c7:	b8 00 00 00 00       	mov    $0x0,%eax
f01005cc:	ee                   	out    %al,(%dx)
f01005cd:	b2 f9                	mov    $0xf9,%dl
f01005cf:	b8 01 00 00 00       	mov    $0x1,%eax
f01005d4:	ee                   	out    %al,(%dx)

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01005d5:	b2 fd                	mov    $0xfd,%dl
f01005d7:	ec                   	in     (%dx),%al
	// Enable rcv interrupts
	outb(COM1+COM_IER, COM_IER_RDI);

	// Clear any preexisting overrun indications and interrupts
	// Serial port doesn't exist if COM_LSR returns 0xFF
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f01005d8:	3c ff                	cmp    $0xff,%al
f01005da:	0f 95 c1             	setne  %cl
f01005dd:	88 0d 34 25 11 f0    	mov    %cl,0xf0112534
f01005e3:	89 f2                	mov    %esi,%edx
f01005e5:	ec                   	in     (%dx),%al
f01005e6:	89 da                	mov    %ebx,%edx
f01005e8:	ec                   	in     (%dx),%al
{
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f01005e9:	84 c9                	test   %cl,%cl
f01005eb:	75 0c                	jne    f01005f9 <cons_init+0xea>
		cprintf("Serial port does not exist!\n");
f01005ed:	c7 04 24 d9 1a 10 f0 	movl   $0xf0101ad9,(%esp)
f01005f4:	e8 f0 04 00 00       	call   f0100ae9 <cprintf>
}
f01005f9:	83 c4 1c             	add    $0x1c,%esp
f01005fc:	5b                   	pop    %ebx
f01005fd:	5e                   	pop    %esi
f01005fe:	5f                   	pop    %edi
f01005ff:	5d                   	pop    %ebp
f0100600:	c3                   	ret    

f0100601 <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f0100601:	55                   	push   %ebp
f0100602:	89 e5                	mov    %esp,%ebp
f0100604:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f0100607:	8b 45 08             	mov    0x8(%ebp),%eax
f010060a:	e8 a8 fc ff ff       	call   f01002b7 <cons_putc>
}
f010060f:	c9                   	leave  
f0100610:	c3                   	ret    

f0100611 <getchar>:

int
getchar(void)
{
f0100611:	55                   	push   %ebp
f0100612:	89 e5                	mov    %esp,%ebp
f0100614:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f0100617:	e8 a9 fe ff ff       	call   f01004c5 <cons_getc>
f010061c:	85 c0                	test   %eax,%eax
f010061e:	74 f7                	je     f0100617 <getchar+0x6>
		/* do nothing */;
	return c;
}
f0100620:	c9                   	leave  
f0100621:	c3                   	ret    

f0100622 <iscons>:

int
iscons(int fdnum)
{
f0100622:	55                   	push   %ebp
f0100623:	89 e5                	mov    %esp,%ebp
	// used by readline
	return 1;
}
f0100625:	b8 01 00 00 00       	mov    $0x1,%eax
f010062a:	5d                   	pop    %ebp
f010062b:	c3                   	ret    
f010062c:	66 90                	xchg   %ax,%ax
f010062e:	66 90                	xchg   %ax,%ax

f0100630 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100630:	55                   	push   %ebp
f0100631:	89 e5                	mov    %esp,%ebp
f0100633:	83 ec 18             	sub    $0x18,%esp
	int i;

	for (i = 0; i < ARRAY_SIZE(commands); i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f0100636:	c7 44 24 08 20 1d 10 	movl   $0xf0101d20,0x8(%esp)
f010063d:	f0 
f010063e:	c7 44 24 04 3e 1d 10 	movl   $0xf0101d3e,0x4(%esp)
f0100645:	f0 
f0100646:	c7 04 24 43 1d 10 f0 	movl   $0xf0101d43,(%esp)
f010064d:	e8 97 04 00 00       	call   f0100ae9 <cprintf>
f0100652:	c7 44 24 08 ac 1d 10 	movl   $0xf0101dac,0x8(%esp)
f0100659:	f0 
f010065a:	c7 44 24 04 4c 1d 10 	movl   $0xf0101d4c,0x4(%esp)
f0100661:	f0 
f0100662:	c7 04 24 43 1d 10 f0 	movl   $0xf0101d43,(%esp)
f0100669:	e8 7b 04 00 00       	call   f0100ae9 <cprintf>
	return 0;
}
f010066e:	b8 00 00 00 00       	mov    $0x0,%eax
f0100673:	c9                   	leave  
f0100674:	c3                   	ret    

f0100675 <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f0100675:	55                   	push   %ebp
f0100676:	89 e5                	mov    %esp,%ebp
f0100678:	83 ec 18             	sub    $0x18,%esp
	extern char _start[], entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f010067b:	c7 04 24 55 1d 10 f0 	movl   $0xf0101d55,(%esp)
f0100682:	e8 62 04 00 00       	call   f0100ae9 <cprintf>
	cprintf("  _start                  %08x (phys)\n", _start);
f0100687:	c7 44 24 04 0c 00 10 	movl   $0x10000c,0x4(%esp)
f010068e:	00 
f010068f:	c7 04 24 d4 1d 10 f0 	movl   $0xf0101dd4,(%esp)
f0100696:	e8 4e 04 00 00       	call   f0100ae9 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
f010069b:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f01006a2:	00 
f01006a3:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f01006aa:	f0 
f01006ab:	c7 04 24 fc 1d 10 f0 	movl   $0xf0101dfc,(%esp)
f01006b2:	e8 32 04 00 00       	call   f0100ae9 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01006b7:	c7 44 24 08 77 1a 10 	movl   $0x101a77,0x8(%esp)
f01006be:	00 
f01006bf:	c7 44 24 04 77 1a 10 	movl   $0xf0101a77,0x4(%esp)
f01006c6:	f0 
f01006c7:	c7 04 24 20 1e 10 f0 	movl   $0xf0101e20,(%esp)
f01006ce:	e8 16 04 00 00       	call   f0100ae9 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f01006d3:	c7 44 24 08 00 23 11 	movl   $0x112300,0x8(%esp)
f01006da:	00 
f01006db:	c7 44 24 04 00 23 11 	movl   $0xf0112300,0x4(%esp)
f01006e2:	f0 
f01006e3:	c7 04 24 44 1e 10 f0 	movl   $0xf0101e44,(%esp)
f01006ea:	e8 fa 03 00 00       	call   f0100ae9 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f01006ef:	c7 44 24 08 70 29 11 	movl   $0x112970,0x8(%esp)
f01006f6:	00 
f01006f7:	c7 44 24 04 70 29 11 	movl   $0xf0112970,0x4(%esp)
f01006fe:	f0 
f01006ff:	c7 04 24 68 1e 10 f0 	movl   $0xf0101e68,(%esp)
f0100706:	e8 de 03 00 00       	call   f0100ae9 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		ROUNDUP(end - entry, 1024) / 1024);
f010070b:	b8 6f 2d 11 f0       	mov    $0xf0112d6f,%eax
f0100710:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
f0100715:	25 00 fc ff ff       	and    $0xfffffc00,%eax
	cprintf("  _start                  %08x (phys)\n", _start);
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f010071a:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f0100720:	85 c0                	test   %eax,%eax
f0100722:	0f 48 c2             	cmovs  %edx,%eax
f0100725:	c1 f8 0a             	sar    $0xa,%eax
f0100728:	89 44 24 04          	mov    %eax,0x4(%esp)
f010072c:	c7 04 24 8c 1e 10 f0 	movl   $0xf0101e8c,(%esp)
f0100733:	e8 b1 03 00 00       	call   f0100ae9 <cprintf>
		ROUNDUP(end - entry, 1024) / 1024);
	return 0;
}
f0100738:	b8 00 00 00 00       	mov    $0x0,%eax
f010073d:	c9                   	leave  
f010073e:	c3                   	ret    

f010073f <mon_backtrace>:

int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f010073f:	55                   	push   %ebp
f0100740:	89 e5                	mov    %esp,%ebp
	// Your code here.
	return 0;
}
f0100742:	b8 00 00 00 00       	mov    $0x0,%eax
f0100747:	5d                   	pop    %ebp
f0100748:	c3                   	ret    

f0100749 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f0100749:	55                   	push   %ebp
f010074a:	89 e5                	mov    %esp,%ebp
f010074c:	57                   	push   %edi
f010074d:	56                   	push   %esi
f010074e:	53                   	push   %ebx
f010074f:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f0100752:	c7 04 24 b8 1e 10 f0 	movl   $0xf0101eb8,(%esp)
f0100759:	e8 8b 03 00 00       	call   f0100ae9 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f010075e:	c7 04 24 dc 1e 10 f0 	movl   $0xf0101edc,(%esp)
f0100765:	e8 7f 03 00 00       	call   f0100ae9 <cprintf>


	while (1) {
		buf = readline("K> ");
f010076a:	c7 04 24 6e 1d 10 f0 	movl   $0xf0101d6e,(%esp)
f0100771:	e8 1a 0c 00 00       	call   f0101390 <readline>
f0100776:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f0100778:	85 c0                	test   %eax,%eax
f010077a:	74 ee                	je     f010076a <monitor+0x21>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f010077c:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f0100783:	be 00 00 00 00       	mov    $0x0,%esi
f0100788:	eb 0a                	jmp    f0100794 <monitor+0x4b>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f010078a:	c6 03 00             	movb   $0x0,(%ebx)
f010078d:	89 f7                	mov    %esi,%edi
f010078f:	8d 5b 01             	lea    0x1(%ebx),%ebx
f0100792:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f0100794:	0f b6 03             	movzbl (%ebx),%eax
f0100797:	84 c0                	test   %al,%al
f0100799:	74 63                	je     f01007fe <monitor+0xb5>
f010079b:	0f be c0             	movsbl %al,%eax
f010079e:	89 44 24 04          	mov    %eax,0x4(%esp)
f01007a2:	c7 04 24 72 1d 10 f0 	movl   $0xf0101d72,(%esp)
f01007a9:	e8 fc 0d 00 00       	call   f01015aa <strchr>
f01007ae:	85 c0                	test   %eax,%eax
f01007b0:	75 d8                	jne    f010078a <monitor+0x41>
			*buf++ = 0;
		if (*buf == 0)
f01007b2:	80 3b 00             	cmpb   $0x0,(%ebx)
f01007b5:	74 47                	je     f01007fe <monitor+0xb5>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f01007b7:	83 fe 0f             	cmp    $0xf,%esi
f01007ba:	75 16                	jne    f01007d2 <monitor+0x89>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f01007bc:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f01007c3:	00 
f01007c4:	c7 04 24 77 1d 10 f0 	movl   $0xf0101d77,(%esp)
f01007cb:	e8 19 03 00 00       	call   f0100ae9 <cprintf>
f01007d0:	eb 98                	jmp    f010076a <monitor+0x21>
			return 0;
		}
		argv[argc++] = buf;
f01007d2:	8d 7e 01             	lea    0x1(%esi),%edi
f01007d5:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
f01007d9:	eb 03                	jmp    f01007de <monitor+0x95>
		while (*buf && !strchr(WHITESPACE, *buf))
			buf++;
f01007db:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f01007de:	0f b6 03             	movzbl (%ebx),%eax
f01007e1:	84 c0                	test   %al,%al
f01007e3:	74 ad                	je     f0100792 <monitor+0x49>
f01007e5:	0f be c0             	movsbl %al,%eax
f01007e8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01007ec:	c7 04 24 72 1d 10 f0 	movl   $0xf0101d72,(%esp)
f01007f3:	e8 b2 0d 00 00       	call   f01015aa <strchr>
f01007f8:	85 c0                	test   %eax,%eax
f01007fa:	74 df                	je     f01007db <monitor+0x92>
f01007fc:	eb 94                	jmp    f0100792 <monitor+0x49>
			buf++;
	}
	argv[argc] = 0;
f01007fe:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f0100805:	00 

	// Lookup and invoke the command
	if (argc == 0)
f0100806:	85 f6                	test   %esi,%esi
f0100808:	0f 84 5c ff ff ff    	je     f010076a <monitor+0x21>
		return 0;
	for (i = 0; i < ARRAY_SIZE(commands); i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f010080e:	c7 44 24 04 3e 1d 10 	movl   $0xf0101d3e,0x4(%esp)
f0100815:	f0 
f0100816:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100819:	89 04 24             	mov    %eax,(%esp)
f010081c:	e8 2b 0d 00 00       	call   f010154c <strcmp>
f0100821:	85 c0                	test   %eax,%eax
f0100823:	74 1b                	je     f0100840 <monitor+0xf7>
f0100825:	c7 44 24 04 4c 1d 10 	movl   $0xf0101d4c,0x4(%esp)
f010082c:	f0 
f010082d:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100830:	89 04 24             	mov    %eax,(%esp)
f0100833:	e8 14 0d 00 00       	call   f010154c <strcmp>
f0100838:	85 c0                	test   %eax,%eax
f010083a:	75 2f                	jne    f010086b <monitor+0x122>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < ARRAY_SIZE(commands); i++) {
f010083c:	b0 01                	mov    $0x1,%al
f010083e:	eb 05                	jmp    f0100845 <monitor+0xfc>
		if (strcmp(argv[0], commands[i].name) == 0)
f0100840:	b8 00 00 00 00       	mov    $0x0,%eax
			return commands[i].func(argc, argv, tf);
f0100845:	8d 14 00             	lea    (%eax,%eax,1),%edx
f0100848:	01 d0                	add    %edx,%eax
f010084a:	8b 4d 08             	mov    0x8(%ebp),%ecx
f010084d:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0100851:	8d 55 a8             	lea    -0x58(%ebp),%edx
f0100854:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100858:	89 34 24             	mov    %esi,(%esp)
f010085b:	ff 14 85 0c 1f 10 f0 	call   *-0xfefe0f4(,%eax,4)


	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f0100862:	85 c0                	test   %eax,%eax
f0100864:	78 1d                	js     f0100883 <monitor+0x13a>
f0100866:	e9 ff fe ff ff       	jmp    f010076a <monitor+0x21>
		return 0;
	for (i = 0; i < ARRAY_SIZE(commands); i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f010086b:	8b 45 a8             	mov    -0x58(%ebp),%eax
f010086e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100872:	c7 04 24 94 1d 10 f0 	movl   $0xf0101d94,(%esp)
f0100879:	e8 6b 02 00 00       	call   f0100ae9 <cprintf>
f010087e:	e9 e7 fe ff ff       	jmp    f010076a <monitor+0x21>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f0100883:	83 c4 5c             	add    $0x5c,%esp
f0100886:	5b                   	pop    %ebx
f0100887:	5e                   	pop    %esi
f0100888:	5f                   	pop    %edi
f0100889:	5d                   	pop    %ebp
f010088a:	c3                   	ret    

f010088b <nvram_read>:
// Detect machine's physical memory setup.
// --------------------------------------------------------------

static int
nvram_read(int r)
{
f010088b:	55                   	push   %ebp
f010088c:	89 e5                	mov    %esp,%ebp
f010088e:	56                   	push   %esi
f010088f:	53                   	push   %ebx
f0100890:	83 ec 10             	sub    $0x10,%esp
f0100893:	89 c3                	mov    %eax,%ebx
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0100895:	89 04 24             	mov    %eax,(%esp)
f0100898:	e8 dc 01 00 00       	call   f0100a79 <mc146818_read>
f010089d:	89 c6                	mov    %eax,%esi
f010089f:	83 c3 01             	add    $0x1,%ebx
f01008a2:	89 1c 24             	mov    %ebx,(%esp)
f01008a5:	e8 cf 01 00 00       	call   f0100a79 <mc146818_read>
f01008aa:	c1 e0 08             	shl    $0x8,%eax
f01008ad:	09 f0                	or     %esi,%eax
}
f01008af:	83 c4 10             	add    $0x10,%esp
f01008b2:	5b                   	pop    %ebx
f01008b3:	5e                   	pop    %esi
f01008b4:	5d                   	pop    %ebp
f01008b5:	c3                   	ret    

f01008b6 <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f01008b6:	55                   	push   %ebp
f01008b7:	89 e5                	mov    %esp,%ebp
f01008b9:	56                   	push   %esi
f01008ba:	53                   	push   %ebx
f01008bb:	83 ec 10             	sub    $0x10,%esp
{
	size_t basemem, extmem, ext16mem, totalmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	basemem = nvram_read(NVRAM_BASELO);
f01008be:	b8 15 00 00 00       	mov    $0x15,%eax
f01008c3:	e8 c3 ff ff ff       	call   f010088b <nvram_read>
f01008c8:	89 c3                	mov    %eax,%ebx
	extmem = nvram_read(NVRAM_EXTLO);
f01008ca:	b8 17 00 00 00       	mov    $0x17,%eax
f01008cf:	e8 b7 ff ff ff       	call   f010088b <nvram_read>
f01008d4:	89 c6                	mov    %eax,%esi
	ext16mem = nvram_read(NVRAM_EXT16LO) * 64;
f01008d6:	b8 34 00 00 00       	mov    $0x34,%eax
f01008db:	e8 ab ff ff ff       	call   f010088b <nvram_read>
f01008e0:	c1 e0 06             	shl    $0x6,%eax
f01008e3:	89 c2                	mov    %eax,%edx

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (ext16mem)
		totalmem = 16 * 1024 + ext16mem;
f01008e5:	8d 80 00 40 00 00    	lea    0x4000(%eax),%eax
	extmem = nvram_read(NVRAM_EXTLO);
	ext16mem = nvram_read(NVRAM_EXT16LO) * 64;

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (ext16mem)
f01008eb:	85 d2                	test   %edx,%edx
f01008ed:	75 0b                	jne    f01008fa <mem_init+0x44>
		totalmem = 16 * 1024 + ext16mem;
	else if (extmem)
		totalmem = 1 * 1024 + extmem;
f01008ef:	8d 86 00 04 00 00    	lea    0x400(%esi),%eax
f01008f5:	85 f6                	test   %esi,%esi
f01008f7:	0f 44 c3             	cmove  %ebx,%eax
	else
		totalmem = basemem;

	npages = totalmem / (PGSIZE / 1024);
f01008fa:	89 c2                	mov    %eax,%edx
f01008fc:	c1 ea 02             	shr    $0x2,%edx
f01008ff:	89 15 64 29 11 f0    	mov    %edx,0xf0112964
	npages_basemem = basemem / (PGSIZE / 1024);
f0100905:	89 da                	mov    %ebx,%edx
f0100907:	c1 ea 02             	shr    $0x2,%edx
f010090a:	89 15 40 25 11 f0    	mov    %edx,0xf0112540

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0100910:	89 c2                	mov    %eax,%edx
f0100912:	29 da                	sub    %ebx,%edx
f0100914:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100918:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f010091c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100920:	c7 04 24 1c 1f 10 f0 	movl   $0xf0101f1c,(%esp)
f0100927:	e8 bd 01 00 00       	call   f0100ae9 <cprintf>
	// Initialize nextfree if this is the first time.
	// 'end' is a magic symbol automatically generated by the linker,
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
f010092c:	83 3d 38 25 11 f0 00 	cmpl   $0x0,0xf0112538
f0100933:	75 0f                	jne    f0100944 <mem_init+0x8e>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100935:	b8 6f 39 11 f0       	mov    $0xf011396f,%eax
f010093a:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f010093f:	a3 38 25 11 f0       	mov    %eax,0xf0112538
	{
		// number of pages requested
		int numPagesRequested = ROUNDUP(n,PGSIZE)/PGSIZE;
		// check if n exceeds memory panic
		//cprintf("%x,%x\n",PADDR(nextfree),numPagesRequested);
		if (npages<=(numPagesRequested + ((uint32_t)PADDR(nextfree)/PGSIZE)))
f0100944:	a1 38 25 11 f0       	mov    0xf0112538,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100949:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010094e:	77 20                	ja     f0100970 <mem_init+0xba>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0100950:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100954:	c7 44 24 08 58 1f 10 	movl   $0xf0101f58,0x8(%esp)
f010095b:	f0 
f010095c:	c7 44 24 04 71 00 00 	movl   $0x71,0x4(%esp)
f0100963:	00 
f0100964:	c7 04 24 f4 1f 10 f0 	movl   $0xf0101ff4,(%esp)
f010096b:	e8 24 f7 ff ff       	call   f0100094 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0100970:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f0100976:	c1 ea 0c             	shr    $0xc,%edx
f0100979:	83 c2 01             	add    $0x1,%edx
f010097c:	3b 15 64 29 11 f0    	cmp    0xf0112964,%edx
f0100982:	72 1c                	jb     f01009a0 <mem_init+0xea>
		{
			panic("boot_alloc: size of requested memory for allocation exceeds memory size\n");
f0100984:	c7 44 24 08 7c 1f 10 	movl   $0xf0101f7c,0x8(%esp)
f010098b:	f0 
f010098c:	c7 44 24 04 73 00 00 	movl   $0x73,0x4(%esp)
f0100993:	00 
f0100994:	c7 04 24 f4 1f 10 f0 	movl   $0xf0101ff4,(%esp)
f010099b:	e8 f4 f6 ff ff       	call   f0100094 <_panic>
			return NULL;
		}
		else
		{
			result = nextfree;
			nextfree = (char *)ROUNDUP(n + (uint32_t)nextfree, PGSIZE);
f01009a0:	8d 90 ff 1f 00 00    	lea    0x1fff(%eax),%edx
f01009a6:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f01009ac:	89 15 38 25 11 f0    	mov    %edx,0xf0112538
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);
f01009b2:	a3 68 29 11 f0       	mov    %eax,0xf0112968
	memset(kern_pgdir, 0, PGSIZE);
f01009b7:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01009be:	00 
f01009bf:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01009c6:	00 
f01009c7:	89 04 24             	mov    %eax,(%esp)
f01009ca:	e8 18 0c 00 00       	call   f01015e7 <memset>
panic("mem_init: This function is not finished\n");
f01009cf:	c7 44 24 08 c8 1f 10 	movl   $0xf0101fc8,0x8(%esp)
f01009d6:	f0 
f01009d7:	c7 44 24 04 9a 00 00 	movl   $0x9a,0x4(%esp)
f01009de:	00 
f01009df:	c7 04 24 f4 1f 10 f0 	movl   $0xf0101ff4,(%esp)
f01009e6:	e8 a9 f6 ff ff       	call   f0100094 <_panic>

f01009eb <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f01009eb:	55                   	push   %ebp
f01009ec:	89 e5                	mov    %esp,%ebp
f01009ee:	53                   	push   %ebx
f01009ef:	8b 1d 3c 25 11 f0    	mov    0xf011253c,%ebx
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f01009f5:	b8 00 00 00 00       	mov    $0x0,%eax
f01009fa:	eb 22                	jmp    f0100a1e <page_init+0x33>
f01009fc:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
		pages[i].pp_ref = 0;
f0100a03:	89 d1                	mov    %edx,%ecx
f0100a05:	03 0d 6c 29 11 f0    	add    0xf011296c,%ecx
f0100a0b:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0100a11:	89 19                	mov    %ebx,(%ecx)
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0100a13:	83 c0 01             	add    $0x1,%eax
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f0100a16:	89 d3                	mov    %edx,%ebx
f0100a18:	03 1d 6c 29 11 f0    	add    0xf011296c,%ebx
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0100a1e:	3b 05 64 29 11 f0    	cmp    0xf0112964,%eax
f0100a24:	72 d6                	jb     f01009fc <page_init+0x11>
f0100a26:	89 1d 3c 25 11 f0    	mov    %ebx,0xf011253c
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
	}
}
f0100a2c:	5b                   	pop    %ebx
f0100a2d:	5d                   	pop    %ebp
f0100a2e:	c3                   	ret    

f0100a2f <page_alloc>:
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct PageInfo *
page_alloc(int alloc_flags)
{
f0100a2f:	55                   	push   %ebp
f0100a30:	89 e5                	mov    %esp,%ebp
	// Fill this function in
	return 0;
}
f0100a32:	b8 00 00 00 00       	mov    $0x0,%eax
f0100a37:	5d                   	pop    %ebp
f0100a38:	c3                   	ret    

f0100a39 <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct PageInfo *pp)
{
f0100a39:	55                   	push   %ebp
f0100a3a:	89 e5                	mov    %esp,%ebp
	// Fill this function in
	// Hint: You may want to panic if pp->pp_ref is nonzero or
	// pp->pp_link is not NULL.
}
f0100a3c:	5d                   	pop    %ebp
f0100a3d:	c3                   	ret    

f0100a3e <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct PageInfo* pp)
{
f0100a3e:	55                   	push   %ebp
f0100a3f:	89 e5                	mov    %esp,%ebp
f0100a41:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f0100a44:	66 83 68 04 01       	subw   $0x1,0x4(%eax)
		page_free(pp);
}
f0100a49:	5d                   	pop    %ebp
f0100a4a:	c3                   	ret    

f0100a4b <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that mainipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f0100a4b:	55                   	push   %ebp
f0100a4c:	89 e5                	mov    %esp,%ebp
	// Fill this function in
	return NULL;
}
f0100a4e:	b8 00 00 00 00       	mov    $0x0,%eax
f0100a53:	5d                   	pop    %ebp
f0100a54:	c3                   	ret    

f0100a55 <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct PageInfo *pp, void *va, int perm)
{
f0100a55:	55                   	push   %ebp
f0100a56:	89 e5                	mov    %esp,%ebp
	// Fill this function in
	return 0;
}
f0100a58:	b8 00 00 00 00       	mov    $0x0,%eax
f0100a5d:	5d                   	pop    %ebp
f0100a5e:	c3                   	ret    

f0100a5f <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct PageInfo *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f0100a5f:	55                   	push   %ebp
f0100a60:	89 e5                	mov    %esp,%ebp
	// Fill this function in
	return NULL;
}
f0100a62:	b8 00 00 00 00       	mov    $0x0,%eax
f0100a67:	5d                   	pop    %ebp
f0100a68:	c3                   	ret    

f0100a69 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f0100a69:	55                   	push   %ebp
f0100a6a:	89 e5                	mov    %esp,%ebp
	// Fill this function in
}
f0100a6c:	5d                   	pop    %ebp
f0100a6d:	c3                   	ret    

f0100a6e <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f0100a6e:	55                   	push   %ebp
f0100a6f:	89 e5                	mov    %esp,%ebp
}

static inline void
invlpg(void *addr)
{
	asm volatile("invlpg (%0)" : : "r" (addr) : "memory");
f0100a71:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100a74:	0f 01 38             	invlpg (%eax)
	// Flush the entry only if we're modifying the current address space.
	// For now, there is only one address space, so always invalidate.
	invlpg(va);
}
f0100a77:	5d                   	pop    %ebp
f0100a78:	c3                   	ret    

f0100a79 <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0100a79:	55                   	push   %ebp
f0100a7a:	89 e5                	mov    %esp,%ebp
f0100a7c:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100a80:	ba 70 00 00 00       	mov    $0x70,%edx
f0100a85:	ee                   	out    %al,(%dx)

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100a86:	b2 71                	mov    $0x71,%dl
f0100a88:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0100a89:	0f b6 c0             	movzbl %al,%eax
}
f0100a8c:	5d                   	pop    %ebp
f0100a8d:	c3                   	ret    

f0100a8e <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0100a8e:	55                   	push   %ebp
f0100a8f:	89 e5                	mov    %esp,%ebp
f0100a91:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100a95:	ba 70 00 00 00       	mov    $0x70,%edx
f0100a9a:	ee                   	out    %al,(%dx)
f0100a9b:	b2 71                	mov    $0x71,%dl
f0100a9d:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100aa0:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0100aa1:	5d                   	pop    %ebp
f0100aa2:	c3                   	ret    

f0100aa3 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0100aa3:	55                   	push   %ebp
f0100aa4:	89 e5                	mov    %esp,%ebp
f0100aa6:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0100aa9:	8b 45 08             	mov    0x8(%ebp),%eax
f0100aac:	89 04 24             	mov    %eax,(%esp)
f0100aaf:	e8 4d fb ff ff       	call   f0100601 <cputchar>
	*cnt++;
}
f0100ab4:	c9                   	leave  
f0100ab5:	c3                   	ret    

f0100ab6 <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0100ab6:	55                   	push   %ebp
f0100ab7:	89 e5                	mov    %esp,%ebp
f0100ab9:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0100abc:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0100ac3:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100ac6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100aca:	8b 45 08             	mov    0x8(%ebp),%eax
f0100acd:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100ad1:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0100ad4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100ad8:	c7 04 24 a3 0a 10 f0 	movl   $0xf0100aa3,(%esp)
f0100adf:	e8 4a 04 00 00       	call   f0100f2e <vprintfmt>
	return cnt;
}
f0100ae4:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0100ae7:	c9                   	leave  
f0100ae8:	c3                   	ret    

f0100ae9 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0100ae9:	55                   	push   %ebp
f0100aea:	89 e5                	mov    %esp,%ebp
f0100aec:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0100aef:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0100af2:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100af6:	8b 45 08             	mov    0x8(%ebp),%eax
f0100af9:	89 04 24             	mov    %eax,(%esp)
f0100afc:	e8 b5 ff ff ff       	call   f0100ab6 <vcprintf>
	va_end(ap);

	return cnt;
}
f0100b01:	c9                   	leave  
f0100b02:	c3                   	ret    

f0100b03 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0100b03:	55                   	push   %ebp
f0100b04:	89 e5                	mov    %esp,%ebp
f0100b06:	57                   	push   %edi
f0100b07:	56                   	push   %esi
f0100b08:	53                   	push   %ebx
f0100b09:	83 ec 10             	sub    $0x10,%esp
f0100b0c:	89 c6                	mov    %eax,%esi
f0100b0e:	89 55 e8             	mov    %edx,-0x18(%ebp)
f0100b11:	89 4d e4             	mov    %ecx,-0x1c(%ebp)
f0100b14:	8b 7d 08             	mov    0x8(%ebp),%edi
	int l = *region_left, r = *region_right, any_matches = 0;
f0100b17:	8b 1a                	mov    (%edx),%ebx
f0100b19:	8b 01                	mov    (%ecx),%eax
f0100b1b:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0100b1e:	c7 45 ec 00 00 00 00 	movl   $0x0,-0x14(%ebp)

	while (l <= r) {
f0100b25:	eb 77                	jmp    f0100b9e <stab_binsearch+0x9b>
		int true_m = (l + r) / 2, m = true_m;
f0100b27:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0100b2a:	01 d8                	add    %ebx,%eax
f0100b2c:	b9 02 00 00 00       	mov    $0x2,%ecx
f0100b31:	99                   	cltd   
f0100b32:	f7 f9                	idiv   %ecx
f0100b34:	89 c1                	mov    %eax,%ecx

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0100b36:	eb 01                	jmp    f0100b39 <stab_binsearch+0x36>
			m--;
f0100b38:	49                   	dec    %ecx

	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0100b39:	39 d9                	cmp    %ebx,%ecx
f0100b3b:	7c 1d                	jl     f0100b5a <stab_binsearch+0x57>
f0100b3d:	6b d1 0c             	imul   $0xc,%ecx,%edx
f0100b40:	0f b6 54 16 04       	movzbl 0x4(%esi,%edx,1),%edx
f0100b45:	39 fa                	cmp    %edi,%edx
f0100b47:	75 ef                	jne    f0100b38 <stab_binsearch+0x35>
f0100b49:	89 4d ec             	mov    %ecx,-0x14(%ebp)
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0100b4c:	6b d1 0c             	imul   $0xc,%ecx,%edx
f0100b4f:	8b 54 16 08          	mov    0x8(%esi,%edx,1),%edx
f0100b53:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0100b56:	73 18                	jae    f0100b70 <stab_binsearch+0x6d>
f0100b58:	eb 05                	jmp    f0100b5f <stab_binsearch+0x5c>

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0100b5a:	8d 58 01             	lea    0x1(%eax),%ebx
			continue;
f0100b5d:	eb 3f                	jmp    f0100b9e <stab_binsearch+0x9b>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0100b5f:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f0100b62:	89 0b                	mov    %ecx,(%ebx)
			l = true_m + 1;
f0100b64:	8d 58 01             	lea    0x1(%eax),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100b67:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f0100b6e:	eb 2e                	jmp    f0100b9e <stab_binsearch+0x9b>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0100b70:	39 55 0c             	cmp    %edx,0xc(%ebp)
f0100b73:	73 15                	jae    f0100b8a <stab_binsearch+0x87>
			*region_right = m - 1;
f0100b75:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0100b78:	48                   	dec    %eax
f0100b79:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0100b7c:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0100b7f:	89 01                	mov    %eax,(%ecx)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100b81:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f0100b88:	eb 14                	jmp    f0100b9e <stab_binsearch+0x9b>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f0100b8a:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0100b8d:	8b 5d ec             	mov    -0x14(%ebp),%ebx
f0100b90:	89 18                	mov    %ebx,(%eax)
			l = m;
			addr++;
f0100b92:	ff 45 0c             	incl   0xc(%ebp)
f0100b95:	89 cb                	mov    %ecx,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100b97:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;

	while (l <= r) {
f0100b9e:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0100ba1:	7e 84                	jle    f0100b27 <stab_binsearch+0x24>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0100ba3:	83 7d ec 00          	cmpl   $0x0,-0x14(%ebp)
f0100ba7:	75 0d                	jne    f0100bb6 <stab_binsearch+0xb3>
		*region_right = *region_left - 1;
f0100ba9:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0100bac:	8b 00                	mov    (%eax),%eax
f0100bae:	48                   	dec    %eax
f0100baf:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0100bb2:	89 07                	mov    %eax,(%edi)
f0100bb4:	eb 22                	jmp    f0100bd8 <stab_binsearch+0xd5>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100bb6:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100bb9:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0100bbb:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f0100bbe:	8b 0b                	mov    (%ebx),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100bc0:	eb 01                	jmp    f0100bc3 <stab_binsearch+0xc0>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
f0100bc2:	48                   	dec    %eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100bc3:	39 c1                	cmp    %eax,%ecx
f0100bc5:	7d 0c                	jge    f0100bd3 <stab_binsearch+0xd0>
f0100bc7:	6b d0 0c             	imul   $0xc,%eax,%edx
		     l > *region_left && stabs[l].n_type != type;
f0100bca:	0f b6 54 16 04       	movzbl 0x4(%esi,%edx,1),%edx
f0100bcf:	39 fa                	cmp    %edi,%edx
f0100bd1:	75 ef                	jne    f0100bc2 <stab_binsearch+0xbf>
		     l--)
			/* do nothing */;
		*region_left = l;
f0100bd3:	8b 7d e8             	mov    -0x18(%ebp),%edi
f0100bd6:	89 07                	mov    %eax,(%edi)
	}
}
f0100bd8:	83 c4 10             	add    $0x10,%esp
f0100bdb:	5b                   	pop    %ebx
f0100bdc:	5e                   	pop    %esi
f0100bdd:	5f                   	pop    %edi
f0100bde:	5d                   	pop    %ebp
f0100bdf:	c3                   	ret    

f0100be0 <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0100be0:	55                   	push   %ebp
f0100be1:	89 e5                	mov    %esp,%ebp
f0100be3:	57                   	push   %edi
f0100be4:	56                   	push   %esi
f0100be5:	53                   	push   %ebx
f0100be6:	83 ec 2c             	sub    $0x2c,%esp
f0100be9:	8b 75 08             	mov    0x8(%ebp),%esi
f0100bec:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0100bef:	c7 03 00 20 10 f0    	movl   $0xf0102000,(%ebx)
	info->eip_line = 0;
f0100bf5:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
	info->eip_fn_name = "<unknown>";
f0100bfc:	c7 43 08 00 20 10 f0 	movl   $0xf0102000,0x8(%ebx)
	info->eip_fn_namelen = 9;
f0100c03:	c7 43 0c 09 00 00 00 	movl   $0x9,0xc(%ebx)
	info->eip_fn_addr = addr;
f0100c0a:	89 73 10             	mov    %esi,0x10(%ebx)
	info->eip_fn_narg = 0;
f0100c0d:	c7 43 14 00 00 00 00 	movl   $0x0,0x14(%ebx)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0100c14:	81 fe ff ff 7f ef    	cmp    $0xef7fffff,%esi
f0100c1a:	76 12                	jbe    f0100c2e <debuginfo_eip+0x4e>
		// Can't search for user-level addresses yet!
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0100c1c:	b8 14 7e 10 f0       	mov    $0xf0107e14,%eax
f0100c21:	3d 71 62 10 f0       	cmp    $0xf0106271,%eax
f0100c26:	0f 86 6b 01 00 00    	jbe    f0100d97 <debuginfo_eip+0x1b7>
f0100c2c:	eb 1c                	jmp    f0100c4a <debuginfo_eip+0x6a>
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
	} else {
		// Can't search for user-level addresses yet!
  	        panic("User address");
f0100c2e:	c7 44 24 08 0a 20 10 	movl   $0xf010200a,0x8(%esp)
f0100c35:	f0 
f0100c36:	c7 44 24 04 7f 00 00 	movl   $0x7f,0x4(%esp)
f0100c3d:	00 
f0100c3e:	c7 04 24 17 20 10 f0 	movl   $0xf0102017,(%esp)
f0100c45:	e8 4a f4 ff ff       	call   f0100094 <_panic>
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0100c4a:	80 3d 13 7e 10 f0 00 	cmpb   $0x0,0xf0107e13
f0100c51:	0f 85 47 01 00 00    	jne    f0100d9e <debuginfo_eip+0x1be>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.

	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0100c57:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0100c5e:	b8 70 62 10 f0       	mov    $0xf0106270,%eax
f0100c63:	2d 38 22 10 f0       	sub    $0xf0102238,%eax
f0100c68:	c1 f8 02             	sar    $0x2,%eax
f0100c6b:	69 c0 ab aa aa aa    	imul   $0xaaaaaaab,%eax,%eax
f0100c71:	83 e8 01             	sub    $0x1,%eax
f0100c74:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0100c77:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100c7b:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f0100c82:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0100c85:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0100c88:	b8 38 22 10 f0       	mov    $0xf0102238,%eax
f0100c8d:	e8 71 fe ff ff       	call   f0100b03 <stab_binsearch>
	if (lfile == 0)
f0100c92:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100c95:	85 c0                	test   %eax,%eax
f0100c97:	0f 84 08 01 00 00    	je     f0100da5 <debuginfo_eip+0x1c5>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0100c9d:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0100ca0:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100ca3:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0100ca6:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100caa:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0100cb1:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0100cb4:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100cb7:	b8 38 22 10 f0       	mov    $0xf0102238,%eax
f0100cbc:	e8 42 fe ff ff       	call   f0100b03 <stab_binsearch>

	if (lfun <= rfun) {
f0100cc1:	8b 7d dc             	mov    -0x24(%ebp),%edi
f0100cc4:	3b 7d d8             	cmp    -0x28(%ebp),%edi
f0100cc7:	7f 2e                	jg     f0100cf7 <debuginfo_eip+0x117>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0100cc9:	6b c7 0c             	imul   $0xc,%edi,%eax
f0100ccc:	8d 90 38 22 10 f0    	lea    -0xfefddc8(%eax),%edx
f0100cd2:	8b 80 38 22 10 f0    	mov    -0xfefddc8(%eax),%eax
f0100cd8:	b9 14 7e 10 f0       	mov    $0xf0107e14,%ecx
f0100cdd:	81 e9 71 62 10 f0    	sub    $0xf0106271,%ecx
f0100ce3:	39 c8                	cmp    %ecx,%eax
f0100ce5:	73 08                	jae    f0100cef <debuginfo_eip+0x10f>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0100ce7:	05 71 62 10 f0       	add    $0xf0106271,%eax
f0100cec:	89 43 08             	mov    %eax,0x8(%ebx)
		info->eip_fn_addr = stabs[lfun].n_value;
f0100cef:	8b 42 08             	mov    0x8(%edx),%eax
f0100cf2:	89 43 10             	mov    %eax,0x10(%ebx)
f0100cf5:	eb 06                	jmp    f0100cfd <debuginfo_eip+0x11d>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0100cf7:	89 73 10             	mov    %esi,0x10(%ebx)
		lline = lfile;
f0100cfa:	8b 7d e4             	mov    -0x1c(%ebp),%edi
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0100cfd:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0100d04:	00 
f0100d05:	8b 43 08             	mov    0x8(%ebx),%eax
f0100d08:	89 04 24             	mov    %eax,(%esp)
f0100d0b:	e8 bb 08 00 00       	call   f01015cb <strfind>
f0100d10:	2b 43 08             	sub    0x8(%ebx),%eax
f0100d13:	89 43 0c             	mov    %eax,0xc(%ebx)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0100d16:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0100d19:	6b c7 0c             	imul   $0xc,%edi,%eax
f0100d1c:	05 38 22 10 f0       	add    $0xf0102238,%eax
f0100d21:	eb 06                	jmp    f0100d29 <debuginfo_eip+0x149>
	       && stabs[lline].n_type != N_SOL
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0100d23:	83 ef 01             	sub    $0x1,%edi
f0100d26:	83 e8 0c             	sub    $0xc,%eax
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0100d29:	39 cf                	cmp    %ecx,%edi
f0100d2b:	7c 33                	jl     f0100d60 <debuginfo_eip+0x180>
	       && stabs[lline].n_type != N_SOL
f0100d2d:	0f b6 50 04          	movzbl 0x4(%eax),%edx
f0100d31:	80 fa 84             	cmp    $0x84,%dl
f0100d34:	74 0b                	je     f0100d41 <debuginfo_eip+0x161>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0100d36:	80 fa 64             	cmp    $0x64,%dl
f0100d39:	75 e8                	jne    f0100d23 <debuginfo_eip+0x143>
f0100d3b:	83 78 08 00          	cmpl   $0x0,0x8(%eax)
f0100d3f:	74 e2                	je     f0100d23 <debuginfo_eip+0x143>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0100d41:	6b ff 0c             	imul   $0xc,%edi,%edi
f0100d44:	8b 87 38 22 10 f0    	mov    -0xfefddc8(%edi),%eax
f0100d4a:	ba 14 7e 10 f0       	mov    $0xf0107e14,%edx
f0100d4f:	81 ea 71 62 10 f0    	sub    $0xf0106271,%edx
f0100d55:	39 d0                	cmp    %edx,%eax
f0100d57:	73 07                	jae    f0100d60 <debuginfo_eip+0x180>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0100d59:	05 71 62 10 f0       	add    $0xf0106271,%eax
f0100d5e:	89 03                	mov    %eax,(%ebx)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0100d60:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0100d63:	8b 75 d8             	mov    -0x28(%ebp),%esi
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;

	return 0;
f0100d66:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0100d6b:	39 f1                	cmp    %esi,%ecx
f0100d6d:	7d 42                	jge    f0100db1 <debuginfo_eip+0x1d1>
		for (lline = lfun + 1;
f0100d6f:	8d 51 01             	lea    0x1(%ecx),%edx
f0100d72:	6b c1 0c             	imul   $0xc,%ecx,%eax
f0100d75:	05 38 22 10 f0       	add    $0xf0102238,%eax
f0100d7a:	eb 07                	jmp    f0100d83 <debuginfo_eip+0x1a3>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
f0100d7c:	83 43 14 01          	addl   $0x1,0x14(%ebx)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0100d80:	83 c2 01             	add    $0x1,%edx


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0100d83:	39 f2                	cmp    %esi,%edx
f0100d85:	74 25                	je     f0100dac <debuginfo_eip+0x1cc>
f0100d87:	83 c0 0c             	add    $0xc,%eax
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0100d8a:	80 78 04 a0          	cmpb   $0xa0,0x4(%eax)
f0100d8e:	74 ec                	je     f0100d7c <debuginfo_eip+0x19c>
		     lline++)
			info->eip_fn_narg++;

	return 0;
f0100d90:	b8 00 00 00 00       	mov    $0x0,%eax
f0100d95:	eb 1a                	jmp    f0100db1 <debuginfo_eip+0x1d1>
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0100d97:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100d9c:	eb 13                	jmp    f0100db1 <debuginfo_eip+0x1d1>
f0100d9e:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100da3:	eb 0c                	jmp    f0100db1 <debuginfo_eip+0x1d1>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0100da5:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100daa:	eb 05                	jmp    f0100db1 <debuginfo_eip+0x1d1>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;

	return 0;
f0100dac:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0100db1:	83 c4 2c             	add    $0x2c,%esp
f0100db4:	5b                   	pop    %ebx
f0100db5:	5e                   	pop    %esi
f0100db6:	5f                   	pop    %edi
f0100db7:	5d                   	pop    %ebp
f0100db8:	c3                   	ret    
f0100db9:	66 90                	xchg   %ax,%ax
f0100dbb:	66 90                	xchg   %ax,%ax
f0100dbd:	66 90                	xchg   %ax,%ax
f0100dbf:	90                   	nop

f0100dc0 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0100dc0:	55                   	push   %ebp
f0100dc1:	89 e5                	mov    %esp,%ebp
f0100dc3:	57                   	push   %edi
f0100dc4:	56                   	push   %esi
f0100dc5:	53                   	push   %ebx
f0100dc6:	83 ec 3c             	sub    $0x3c,%esp
f0100dc9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0100dcc:	89 d7                	mov    %edx,%edi
f0100dce:	8b 45 08             	mov    0x8(%ebp),%eax
f0100dd1:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0100dd4:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100dd7:	89 c3                	mov    %eax,%ebx
f0100dd9:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0100ddc:	8b 45 10             	mov    0x10(%ebp),%eax
f0100ddf:	8b 75 14             	mov    0x14(%ebp),%esi
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0100de2:	b9 00 00 00 00       	mov    $0x0,%ecx
f0100de7:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0100dea:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0100ded:	39 d9                	cmp    %ebx,%ecx
f0100def:	72 05                	jb     f0100df6 <printnum+0x36>
f0100df1:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f0100df4:	77 69                	ja     f0100e5f <printnum+0x9f>
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0100df6:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0100df9:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0100dfd:	83 ee 01             	sub    $0x1,%esi
f0100e00:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0100e04:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100e08:	8b 44 24 08          	mov    0x8(%esp),%eax
f0100e0c:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0100e10:	89 c3                	mov    %eax,%ebx
f0100e12:	89 d6                	mov    %edx,%esi
f0100e14:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0100e17:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0100e1a:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100e1e:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0100e22:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100e25:	89 04 24             	mov    %eax,(%esp)
f0100e28:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100e2b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100e2f:	e8 bc 09 00 00       	call   f01017f0 <__udivdi3>
f0100e34:	89 d9                	mov    %ebx,%ecx
f0100e36:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0100e3a:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0100e3e:	89 04 24             	mov    %eax,(%esp)
f0100e41:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100e45:	89 fa                	mov    %edi,%edx
f0100e47:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100e4a:	e8 71 ff ff ff       	call   f0100dc0 <printnum>
f0100e4f:	eb 1b                	jmp    f0100e6c <printnum+0xac>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f0100e51:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100e55:	8b 45 18             	mov    0x18(%ebp),%eax
f0100e58:	89 04 24             	mov    %eax,(%esp)
f0100e5b:	ff d3                	call   *%ebx
f0100e5d:	eb 03                	jmp    f0100e62 <printnum+0xa2>
f0100e5f:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0100e62:	83 ee 01             	sub    $0x1,%esi
f0100e65:	85 f6                	test   %esi,%esi
f0100e67:	7f e8                	jg     f0100e51 <printnum+0x91>
f0100e69:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0100e6c:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100e70:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0100e74:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100e77:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100e7a:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100e7e:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100e82:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100e85:	89 04 24             	mov    %eax,(%esp)
f0100e88:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100e8b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100e8f:	e8 8c 0a 00 00       	call   f0101920 <__umoddi3>
f0100e94:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100e98:	0f be 80 25 20 10 f0 	movsbl -0xfefdfdb(%eax),%eax
f0100e9f:	89 04 24             	mov    %eax,(%esp)
f0100ea2:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100ea5:	ff d0                	call   *%eax
}
f0100ea7:	83 c4 3c             	add    $0x3c,%esp
f0100eaa:	5b                   	pop    %ebx
f0100eab:	5e                   	pop    %esi
f0100eac:	5f                   	pop    %edi
f0100ead:	5d                   	pop    %ebp
f0100eae:	c3                   	ret    

f0100eaf <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0100eaf:	55                   	push   %ebp
f0100eb0:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0100eb2:	83 fa 01             	cmp    $0x1,%edx
f0100eb5:	7e 0e                	jle    f0100ec5 <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f0100eb7:	8b 10                	mov    (%eax),%edx
f0100eb9:	8d 4a 08             	lea    0x8(%edx),%ecx
f0100ebc:	89 08                	mov    %ecx,(%eax)
f0100ebe:	8b 02                	mov    (%edx),%eax
f0100ec0:	8b 52 04             	mov    0x4(%edx),%edx
f0100ec3:	eb 22                	jmp    f0100ee7 <getuint+0x38>
	else if (lflag)
f0100ec5:	85 d2                	test   %edx,%edx
f0100ec7:	74 10                	je     f0100ed9 <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f0100ec9:	8b 10                	mov    (%eax),%edx
f0100ecb:	8d 4a 04             	lea    0x4(%edx),%ecx
f0100ece:	89 08                	mov    %ecx,(%eax)
f0100ed0:	8b 02                	mov    (%edx),%eax
f0100ed2:	ba 00 00 00 00       	mov    $0x0,%edx
f0100ed7:	eb 0e                	jmp    f0100ee7 <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f0100ed9:	8b 10                	mov    (%eax),%edx
f0100edb:	8d 4a 04             	lea    0x4(%edx),%ecx
f0100ede:	89 08                	mov    %ecx,(%eax)
f0100ee0:	8b 02                	mov    (%edx),%eax
f0100ee2:	ba 00 00 00 00       	mov    $0x0,%edx
}
f0100ee7:	5d                   	pop    %ebp
f0100ee8:	c3                   	ret    

f0100ee9 <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f0100ee9:	55                   	push   %ebp
f0100eea:	89 e5                	mov    %esp,%ebp
f0100eec:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0100eef:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0100ef3:	8b 10                	mov    (%eax),%edx
f0100ef5:	3b 50 04             	cmp    0x4(%eax),%edx
f0100ef8:	73 0a                	jae    f0100f04 <sprintputch+0x1b>
		*b->buf++ = ch;
f0100efa:	8d 4a 01             	lea    0x1(%edx),%ecx
f0100efd:	89 08                	mov    %ecx,(%eax)
f0100eff:	8b 45 08             	mov    0x8(%ebp),%eax
f0100f02:	88 02                	mov    %al,(%edx)
}
f0100f04:	5d                   	pop    %ebp
f0100f05:	c3                   	ret    

f0100f06 <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f0100f06:	55                   	push   %ebp
f0100f07:	89 e5                	mov    %esp,%ebp
f0100f09:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0100f0c:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0100f0f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100f13:	8b 45 10             	mov    0x10(%ebp),%eax
f0100f16:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100f1a:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100f1d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100f21:	8b 45 08             	mov    0x8(%ebp),%eax
f0100f24:	89 04 24             	mov    %eax,(%esp)
f0100f27:	e8 02 00 00 00       	call   f0100f2e <vprintfmt>
	va_end(ap);
}
f0100f2c:	c9                   	leave  
f0100f2d:	c3                   	ret    

f0100f2e <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f0100f2e:	55                   	push   %ebp
f0100f2f:	89 e5                	mov    %esp,%ebp
f0100f31:	57                   	push   %edi
f0100f32:	56                   	push   %esi
f0100f33:	53                   	push   %ebx
f0100f34:	83 ec 3c             	sub    $0x3c,%esp
f0100f37:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0100f3a:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0100f3d:	eb 14                	jmp    f0100f53 <vprintfmt+0x25>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f0100f3f:	85 c0                	test   %eax,%eax
f0100f41:	0f 84 b3 03 00 00    	je     f01012fa <vprintfmt+0x3cc>
				return;
			putch(ch, putdat);
f0100f47:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100f4b:	89 04 24             	mov    %eax,(%esp)
f0100f4e:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0100f51:	89 f3                	mov    %esi,%ebx
f0100f53:	8d 73 01             	lea    0x1(%ebx),%esi
f0100f56:	0f b6 03             	movzbl (%ebx),%eax
f0100f59:	83 f8 25             	cmp    $0x25,%eax
f0100f5c:	75 e1                	jne    f0100f3f <vprintfmt+0x11>
f0100f5e:	c6 45 d8 20          	movb   $0x20,-0x28(%ebp)
f0100f62:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0100f69:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f0100f70:	c7 45 dc ff ff ff ff 	movl   $0xffffffff,-0x24(%ebp)
f0100f77:	ba 00 00 00 00       	mov    $0x0,%edx
f0100f7c:	eb 1d                	jmp    f0100f9b <vprintfmt+0x6d>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100f7e:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f0100f80:	c6 45 d8 2d          	movb   $0x2d,-0x28(%ebp)
f0100f84:	eb 15                	jmp    f0100f9b <vprintfmt+0x6d>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100f86:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;

		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0100f88:	c6 45 d8 30          	movb   $0x30,-0x28(%ebp)
f0100f8c:	eb 0d                	jmp    f0100f9b <vprintfmt+0x6d>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f0100f8e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100f91:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0100f94:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100f9b:	8d 5e 01             	lea    0x1(%esi),%ebx
f0100f9e:	0f b6 0e             	movzbl (%esi),%ecx
f0100fa1:	0f b6 c1             	movzbl %cl,%eax
f0100fa4:	83 e9 23             	sub    $0x23,%ecx
f0100fa7:	80 f9 55             	cmp    $0x55,%cl
f0100faa:	0f 87 2a 03 00 00    	ja     f01012da <vprintfmt+0x3ac>
f0100fb0:	0f b6 c9             	movzbl %cl,%ecx
f0100fb3:	ff 24 8d b4 20 10 f0 	jmp    *-0xfefdf4c(,%ecx,4)
f0100fba:	89 de                	mov    %ebx,%esi
f0100fbc:	b9 00 00 00 00       	mov    $0x0,%ecx
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0100fc1:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f0100fc4:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f0100fc8:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0100fcb:	8d 58 d0             	lea    -0x30(%eax),%ebx
f0100fce:	83 fb 09             	cmp    $0x9,%ebx
f0100fd1:	77 36                	ja     f0101009 <vprintfmt+0xdb>
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f0100fd3:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
				ch = *fmt;
				if (ch < '0' || ch > '9')
					break;
			}
f0100fd6:	eb e9                	jmp    f0100fc1 <vprintfmt+0x93>
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0100fd8:	8b 45 14             	mov    0x14(%ebp),%eax
f0100fdb:	8d 48 04             	lea    0x4(%eax),%ecx
f0100fde:	89 4d 14             	mov    %ecx,0x14(%ebp)
f0100fe1:	8b 00                	mov    (%eax),%eax
f0100fe3:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100fe6:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0100fe8:	eb 22                	jmp    f010100c <vprintfmt+0xde>
f0100fea:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0100fed:	85 c9                	test   %ecx,%ecx
f0100fef:	b8 00 00 00 00       	mov    $0x0,%eax
f0100ff4:	0f 49 c1             	cmovns %ecx,%eax
f0100ff7:	89 45 dc             	mov    %eax,-0x24(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100ffa:	89 de                	mov    %ebx,%esi
f0100ffc:	eb 9d                	jmp    f0100f9b <vprintfmt+0x6d>
f0100ffe:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0101000:	c7 45 e0 01 00 00 00 	movl   $0x1,-0x20(%ebp)
			goto reswitch;
f0101007:	eb 92                	jmp    f0100f9b <vprintfmt+0x6d>
f0101009:	89 4d d4             	mov    %ecx,-0x2c(%ebp)

		process_precision:
			if (width < 0)
f010100c:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f0101010:	79 89                	jns    f0100f9b <vprintfmt+0x6d>
f0101012:	e9 77 ff ff ff       	jmp    f0100f8e <vprintfmt+0x60>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0101017:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010101a:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f010101c:	e9 7a ff ff ff       	jmp    f0100f9b <vprintfmt+0x6d>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f0101021:	8b 45 14             	mov    0x14(%ebp),%eax
f0101024:	8d 50 04             	lea    0x4(%eax),%edx
f0101027:	89 55 14             	mov    %edx,0x14(%ebp)
f010102a:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010102e:	8b 00                	mov    (%eax),%eax
f0101030:	89 04 24             	mov    %eax,(%esp)
f0101033:	ff 55 08             	call   *0x8(%ebp)
			break;
f0101036:	e9 18 ff ff ff       	jmp    f0100f53 <vprintfmt+0x25>

		// error message
		case 'e':
			err = va_arg(ap, int);
f010103b:	8b 45 14             	mov    0x14(%ebp),%eax
f010103e:	8d 50 04             	lea    0x4(%eax),%edx
f0101041:	89 55 14             	mov    %edx,0x14(%ebp)
f0101044:	8b 00                	mov    (%eax),%eax
f0101046:	99                   	cltd   
f0101047:	31 d0                	xor    %edx,%eax
f0101049:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f010104b:	83 f8 06             	cmp    $0x6,%eax
f010104e:	7f 0b                	jg     f010105b <vprintfmt+0x12d>
f0101050:	8b 14 85 0c 22 10 f0 	mov    -0xfefddf4(,%eax,4),%edx
f0101057:	85 d2                	test   %edx,%edx
f0101059:	75 20                	jne    f010107b <vprintfmt+0x14d>
				printfmt(putch, putdat, "error %d", err);
f010105b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010105f:	c7 44 24 08 3d 20 10 	movl   $0xf010203d,0x8(%esp)
f0101066:	f0 
f0101067:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010106b:	8b 45 08             	mov    0x8(%ebp),%eax
f010106e:	89 04 24             	mov    %eax,(%esp)
f0101071:	e8 90 fe ff ff       	call   f0100f06 <printfmt>
f0101076:	e9 d8 fe ff ff       	jmp    f0100f53 <vprintfmt+0x25>
			else
				printfmt(putch, putdat, "%s", p);
f010107b:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010107f:	c7 44 24 08 46 20 10 	movl   $0xf0102046,0x8(%esp)
f0101086:	f0 
f0101087:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010108b:	8b 45 08             	mov    0x8(%ebp),%eax
f010108e:	89 04 24             	mov    %eax,(%esp)
f0101091:	e8 70 fe ff ff       	call   f0100f06 <printfmt>
f0101096:	e9 b8 fe ff ff       	jmp    f0100f53 <vprintfmt+0x25>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010109b:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f010109e:	8b 45 dc             	mov    -0x24(%ebp),%eax
f01010a1:	89 45 d0             	mov    %eax,-0x30(%ebp)
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f01010a4:	8b 45 14             	mov    0x14(%ebp),%eax
f01010a7:	8d 50 04             	lea    0x4(%eax),%edx
f01010aa:	89 55 14             	mov    %edx,0x14(%ebp)
f01010ad:	8b 30                	mov    (%eax),%esi
				p = "(null)";
f01010af:	85 f6                	test   %esi,%esi
f01010b1:	b8 36 20 10 f0       	mov    $0xf0102036,%eax
f01010b6:	0f 44 f0             	cmove  %eax,%esi
			if (width > 0 && padc != '-')
f01010b9:	80 7d d8 2d          	cmpb   $0x2d,-0x28(%ebp)
f01010bd:	0f 84 97 00 00 00    	je     f010115a <vprintfmt+0x22c>
f01010c3:	83 7d d0 00          	cmpl   $0x0,-0x30(%ebp)
f01010c7:	0f 8e 9b 00 00 00    	jle    f0101168 <vprintfmt+0x23a>
				for (width -= strnlen(p, precision); width > 0; width--)
f01010cd:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01010d1:	89 34 24             	mov    %esi,(%esp)
f01010d4:	e8 9f 03 00 00       	call   f0101478 <strnlen>
f01010d9:	8b 55 d0             	mov    -0x30(%ebp),%edx
f01010dc:	29 c2                	sub    %eax,%edx
f01010de:	89 55 d0             	mov    %edx,-0x30(%ebp)
					putch(padc, putdat);
f01010e1:	0f be 45 d8          	movsbl -0x28(%ebp),%eax
f01010e5:	89 45 dc             	mov    %eax,-0x24(%ebp)
f01010e8:	89 75 d8             	mov    %esi,-0x28(%ebp)
f01010eb:	8b 75 08             	mov    0x8(%ebp),%esi
f01010ee:	89 5d 10             	mov    %ebx,0x10(%ebp)
f01010f1:	89 d3                	mov    %edx,%ebx
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f01010f3:	eb 0f                	jmp    f0101104 <vprintfmt+0x1d6>
					putch(padc, putdat);
f01010f5:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01010f9:	8b 45 dc             	mov    -0x24(%ebp),%eax
f01010fc:	89 04 24             	mov    %eax,(%esp)
f01010ff:	ff d6                	call   *%esi
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0101101:	83 eb 01             	sub    $0x1,%ebx
f0101104:	85 db                	test   %ebx,%ebx
f0101106:	7f ed                	jg     f01010f5 <vprintfmt+0x1c7>
f0101108:	8b 75 d8             	mov    -0x28(%ebp),%esi
f010110b:	8b 55 d0             	mov    -0x30(%ebp),%edx
f010110e:	85 d2                	test   %edx,%edx
f0101110:	b8 00 00 00 00       	mov    $0x0,%eax
f0101115:	0f 49 c2             	cmovns %edx,%eax
f0101118:	29 c2                	sub    %eax,%edx
f010111a:	89 7d 0c             	mov    %edi,0xc(%ebp)
f010111d:	89 d7                	mov    %edx,%edi
f010111f:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0101122:	eb 50                	jmp    f0101174 <vprintfmt+0x246>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f0101124:	83 7d e0 00          	cmpl   $0x0,-0x20(%ebp)
f0101128:	74 1e                	je     f0101148 <vprintfmt+0x21a>
f010112a:	0f be d2             	movsbl %dl,%edx
f010112d:	83 ea 20             	sub    $0x20,%edx
f0101130:	83 fa 5e             	cmp    $0x5e,%edx
f0101133:	76 13                	jbe    f0101148 <vprintfmt+0x21a>
					putch('?', putdat);
f0101135:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101138:	89 44 24 04          	mov    %eax,0x4(%esp)
f010113c:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f0101143:	ff 55 08             	call   *0x8(%ebp)
f0101146:	eb 0d                	jmp    f0101155 <vprintfmt+0x227>
				else
					putch(ch, putdat);
f0101148:	8b 55 0c             	mov    0xc(%ebp),%edx
f010114b:	89 54 24 04          	mov    %edx,0x4(%esp)
f010114f:	89 04 24             	mov    %eax,(%esp)
f0101152:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0101155:	83 ef 01             	sub    $0x1,%edi
f0101158:	eb 1a                	jmp    f0101174 <vprintfmt+0x246>
f010115a:	89 7d 0c             	mov    %edi,0xc(%ebp)
f010115d:	8b 7d dc             	mov    -0x24(%ebp),%edi
f0101160:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0101163:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0101166:	eb 0c                	jmp    f0101174 <vprintfmt+0x246>
f0101168:	89 7d 0c             	mov    %edi,0xc(%ebp)
f010116b:	8b 7d dc             	mov    -0x24(%ebp),%edi
f010116e:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0101171:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0101174:	83 c6 01             	add    $0x1,%esi
f0101177:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f010117b:	0f be c2             	movsbl %dl,%eax
f010117e:	85 c0                	test   %eax,%eax
f0101180:	74 27                	je     f01011a9 <vprintfmt+0x27b>
f0101182:	85 db                	test   %ebx,%ebx
f0101184:	78 9e                	js     f0101124 <vprintfmt+0x1f6>
f0101186:	83 eb 01             	sub    $0x1,%ebx
f0101189:	79 99                	jns    f0101124 <vprintfmt+0x1f6>
f010118b:	89 f8                	mov    %edi,%eax
f010118d:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0101190:	8b 75 08             	mov    0x8(%ebp),%esi
f0101193:	89 c3                	mov    %eax,%ebx
f0101195:	eb 1a                	jmp    f01011b1 <vprintfmt+0x283>
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0101197:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010119b:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f01011a2:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01011a4:	83 eb 01             	sub    $0x1,%ebx
f01011a7:	eb 08                	jmp    f01011b1 <vprintfmt+0x283>
f01011a9:	89 fb                	mov    %edi,%ebx
f01011ab:	8b 75 08             	mov    0x8(%ebp),%esi
f01011ae:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01011b1:	85 db                	test   %ebx,%ebx
f01011b3:	7f e2                	jg     f0101197 <vprintfmt+0x269>
f01011b5:	89 75 08             	mov    %esi,0x8(%ebp)
f01011b8:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01011bb:	e9 93 fd ff ff       	jmp    f0100f53 <vprintfmt+0x25>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f01011c0:	83 fa 01             	cmp    $0x1,%edx
f01011c3:	7e 16                	jle    f01011db <vprintfmt+0x2ad>
		return va_arg(*ap, long long);
f01011c5:	8b 45 14             	mov    0x14(%ebp),%eax
f01011c8:	8d 50 08             	lea    0x8(%eax),%edx
f01011cb:	89 55 14             	mov    %edx,0x14(%ebp)
f01011ce:	8b 50 04             	mov    0x4(%eax),%edx
f01011d1:	8b 00                	mov    (%eax),%eax
f01011d3:	89 45 e0             	mov    %eax,-0x20(%ebp)
f01011d6:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f01011d9:	eb 32                	jmp    f010120d <vprintfmt+0x2df>
	else if (lflag)
f01011db:	85 d2                	test   %edx,%edx
f01011dd:	74 18                	je     f01011f7 <vprintfmt+0x2c9>
		return va_arg(*ap, long);
f01011df:	8b 45 14             	mov    0x14(%ebp),%eax
f01011e2:	8d 50 04             	lea    0x4(%eax),%edx
f01011e5:	89 55 14             	mov    %edx,0x14(%ebp)
f01011e8:	8b 30                	mov    (%eax),%esi
f01011ea:	89 75 e0             	mov    %esi,-0x20(%ebp)
f01011ed:	89 f0                	mov    %esi,%eax
f01011ef:	c1 f8 1f             	sar    $0x1f,%eax
f01011f2:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01011f5:	eb 16                	jmp    f010120d <vprintfmt+0x2df>
	else
		return va_arg(*ap, int);
f01011f7:	8b 45 14             	mov    0x14(%ebp),%eax
f01011fa:	8d 50 04             	lea    0x4(%eax),%edx
f01011fd:	89 55 14             	mov    %edx,0x14(%ebp)
f0101200:	8b 30                	mov    (%eax),%esi
f0101202:	89 75 e0             	mov    %esi,-0x20(%ebp)
f0101205:	89 f0                	mov    %esi,%eax
f0101207:	c1 f8 1f             	sar    $0x1f,%eax
f010120a:	89 45 e4             	mov    %eax,-0x1c(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f010120d:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0101210:	8b 55 e4             	mov    -0x1c(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f0101213:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f0101218:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f010121c:	0f 89 80 00 00 00    	jns    f01012a2 <vprintfmt+0x374>
				putch('-', putdat);
f0101222:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101226:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f010122d:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f0101230:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0101233:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f0101236:	f7 d8                	neg    %eax
f0101238:	83 d2 00             	adc    $0x0,%edx
f010123b:	f7 da                	neg    %edx
			}
			base = 10;
f010123d:	b9 0a 00 00 00       	mov    $0xa,%ecx
f0101242:	eb 5e                	jmp    f01012a2 <vprintfmt+0x374>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f0101244:	8d 45 14             	lea    0x14(%ebp),%eax
f0101247:	e8 63 fc ff ff       	call   f0100eaf <getuint>
			base = 10;
f010124c:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f0101251:	eb 4f                	jmp    f01012a2 <vprintfmt+0x374>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
				num = getuint(&ap,lflag);
f0101253:	8d 45 14             	lea    0x14(%ebp),%eax
f0101256:	e8 54 fc ff ff       	call   f0100eaf <getuint>
			base = 8;
f010125b:	b9 08 00 00 00       	mov    $0x8,%ecx
			goto number;
f0101260:	eb 40                	jmp    f01012a2 <vprintfmt+0x374>
			//break;

		// pointer
		case 'p':
			putch('0', putdat);
f0101262:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101266:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f010126d:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f0101270:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101274:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f010127b:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f010127e:	8b 45 14             	mov    0x14(%ebp),%eax
f0101281:	8d 50 04             	lea    0x4(%eax),%edx
f0101284:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f0101287:	8b 00                	mov    (%eax),%eax
f0101289:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f010128e:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f0101293:	eb 0d                	jmp    f01012a2 <vprintfmt+0x374>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f0101295:	8d 45 14             	lea    0x14(%ebp),%eax
f0101298:	e8 12 fc ff ff       	call   f0100eaf <getuint>
			base = 16;
f010129d:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f01012a2:	0f be 75 d8          	movsbl -0x28(%ebp),%esi
f01012a6:	89 74 24 10          	mov    %esi,0x10(%esp)
f01012aa:	8b 75 dc             	mov    -0x24(%ebp),%esi
f01012ad:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01012b1:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01012b5:	89 04 24             	mov    %eax,(%esp)
f01012b8:	89 54 24 04          	mov    %edx,0x4(%esp)
f01012bc:	89 fa                	mov    %edi,%edx
f01012be:	8b 45 08             	mov    0x8(%ebp),%eax
f01012c1:	e8 fa fa ff ff       	call   f0100dc0 <printnum>
			break;
f01012c6:	e9 88 fc ff ff       	jmp    f0100f53 <vprintfmt+0x25>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f01012cb:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01012cf:	89 04 24             	mov    %eax,(%esp)
f01012d2:	ff 55 08             	call   *0x8(%ebp)
			break;
f01012d5:	e9 79 fc ff ff       	jmp    f0100f53 <vprintfmt+0x25>

		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f01012da:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01012de:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f01012e5:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f01012e8:	89 f3                	mov    %esi,%ebx
f01012ea:	eb 03                	jmp    f01012ef <vprintfmt+0x3c1>
f01012ec:	83 eb 01             	sub    $0x1,%ebx
f01012ef:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f01012f3:	75 f7                	jne    f01012ec <vprintfmt+0x3be>
f01012f5:	e9 59 fc ff ff       	jmp    f0100f53 <vprintfmt+0x25>
				/* do nothing */;
			break;
		}
	}
}
f01012fa:	83 c4 3c             	add    $0x3c,%esp
f01012fd:	5b                   	pop    %ebx
f01012fe:	5e                   	pop    %esi
f01012ff:	5f                   	pop    %edi
f0101300:	5d                   	pop    %ebp
f0101301:	c3                   	ret    

f0101302 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0101302:	55                   	push   %ebp
f0101303:	89 e5                	mov    %esp,%ebp
f0101305:	83 ec 28             	sub    $0x28,%esp
f0101308:	8b 45 08             	mov    0x8(%ebp),%eax
f010130b:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f010130e:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0101311:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f0101315:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f0101318:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f010131f:	85 c0                	test   %eax,%eax
f0101321:	74 30                	je     f0101353 <vsnprintf+0x51>
f0101323:	85 d2                	test   %edx,%edx
f0101325:	7e 2c                	jle    f0101353 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f0101327:	8b 45 14             	mov    0x14(%ebp),%eax
f010132a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010132e:	8b 45 10             	mov    0x10(%ebp),%eax
f0101331:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101335:	8d 45 ec             	lea    -0x14(%ebp),%eax
f0101338:	89 44 24 04          	mov    %eax,0x4(%esp)
f010133c:	c7 04 24 e9 0e 10 f0 	movl   $0xf0100ee9,(%esp)
f0101343:	e8 e6 fb ff ff       	call   f0100f2e <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f0101348:	8b 45 ec             	mov    -0x14(%ebp),%eax
f010134b:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f010134e:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101351:	eb 05                	jmp    f0101358 <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f0101353:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f0101358:	c9                   	leave  
f0101359:	c3                   	ret    

f010135a <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f010135a:	55                   	push   %ebp
f010135b:	89 e5                	mov    %esp,%ebp
f010135d:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0101360:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f0101363:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101367:	8b 45 10             	mov    0x10(%ebp),%eax
f010136a:	89 44 24 08          	mov    %eax,0x8(%esp)
f010136e:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101371:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101375:	8b 45 08             	mov    0x8(%ebp),%eax
f0101378:	89 04 24             	mov    %eax,(%esp)
f010137b:	e8 82 ff ff ff       	call   f0101302 <vsnprintf>
	va_end(ap);

	return rc;
}
f0101380:	c9                   	leave  
f0101381:	c3                   	ret    
f0101382:	66 90                	xchg   %ax,%ax
f0101384:	66 90                	xchg   %ax,%ax
f0101386:	66 90                	xchg   %ax,%ax
f0101388:	66 90                	xchg   %ax,%ax
f010138a:	66 90                	xchg   %ax,%ax
f010138c:	66 90                	xchg   %ax,%ax
f010138e:	66 90                	xchg   %ax,%ax

f0101390 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0101390:	55                   	push   %ebp
f0101391:	89 e5                	mov    %esp,%ebp
f0101393:	57                   	push   %edi
f0101394:	56                   	push   %esi
f0101395:	53                   	push   %ebx
f0101396:	83 ec 1c             	sub    $0x1c,%esp
f0101399:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f010139c:	85 c0                	test   %eax,%eax
f010139e:	74 10                	je     f01013b0 <readline+0x20>
		cprintf("%s", prompt);
f01013a0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01013a4:	c7 04 24 46 20 10 f0 	movl   $0xf0102046,(%esp)
f01013ab:	e8 39 f7 ff ff       	call   f0100ae9 <cprintf>

	i = 0;
	echoing = iscons(0);
f01013b0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01013b7:	e8 66 f2 ff ff       	call   f0100622 <iscons>
f01013bc:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f01013be:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f01013c3:	e8 49 f2 ff ff       	call   f0100611 <getchar>
f01013c8:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f01013ca:	85 c0                	test   %eax,%eax
f01013cc:	79 17                	jns    f01013e5 <readline+0x55>
			cprintf("read error: %e\n", c);
f01013ce:	89 44 24 04          	mov    %eax,0x4(%esp)
f01013d2:	c7 04 24 28 22 10 f0 	movl   $0xf0102228,(%esp)
f01013d9:	e8 0b f7 ff ff       	call   f0100ae9 <cprintf>
			return NULL;
f01013de:	b8 00 00 00 00       	mov    $0x0,%eax
f01013e3:	eb 6d                	jmp    f0101452 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f01013e5:	83 f8 7f             	cmp    $0x7f,%eax
f01013e8:	74 05                	je     f01013ef <readline+0x5f>
f01013ea:	83 f8 08             	cmp    $0x8,%eax
f01013ed:	75 19                	jne    f0101408 <readline+0x78>
f01013ef:	85 f6                	test   %esi,%esi
f01013f1:	7e 15                	jle    f0101408 <readline+0x78>
			if (echoing)
f01013f3:	85 ff                	test   %edi,%edi
f01013f5:	74 0c                	je     f0101403 <readline+0x73>
				cputchar('\b');
f01013f7:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f01013fe:	e8 fe f1 ff ff       	call   f0100601 <cputchar>
			i--;
f0101403:	83 ee 01             	sub    $0x1,%esi
f0101406:	eb bb                	jmp    f01013c3 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0101408:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f010140e:	7f 1c                	jg     f010142c <readline+0x9c>
f0101410:	83 fb 1f             	cmp    $0x1f,%ebx
f0101413:	7e 17                	jle    f010142c <readline+0x9c>
			if (echoing)
f0101415:	85 ff                	test   %edi,%edi
f0101417:	74 08                	je     f0101421 <readline+0x91>
				cputchar(c);
f0101419:	89 1c 24             	mov    %ebx,(%esp)
f010141c:	e8 e0 f1 ff ff       	call   f0100601 <cputchar>
			buf[i++] = c;
f0101421:	88 9e 60 25 11 f0    	mov    %bl,-0xfeedaa0(%esi)
f0101427:	8d 76 01             	lea    0x1(%esi),%esi
f010142a:	eb 97                	jmp    f01013c3 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f010142c:	83 fb 0d             	cmp    $0xd,%ebx
f010142f:	74 05                	je     f0101436 <readline+0xa6>
f0101431:	83 fb 0a             	cmp    $0xa,%ebx
f0101434:	75 8d                	jne    f01013c3 <readline+0x33>
			if (echoing)
f0101436:	85 ff                	test   %edi,%edi
f0101438:	74 0c                	je     f0101446 <readline+0xb6>
				cputchar('\n');
f010143a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0101441:	e8 bb f1 ff ff       	call   f0100601 <cputchar>
			buf[i] = 0;
f0101446:	c6 86 60 25 11 f0 00 	movb   $0x0,-0xfeedaa0(%esi)
			return buf;
f010144d:	b8 60 25 11 f0       	mov    $0xf0112560,%eax
		}
	}
}
f0101452:	83 c4 1c             	add    $0x1c,%esp
f0101455:	5b                   	pop    %ebx
f0101456:	5e                   	pop    %esi
f0101457:	5f                   	pop    %edi
f0101458:	5d                   	pop    %ebp
f0101459:	c3                   	ret    
f010145a:	66 90                	xchg   %ax,%ax
f010145c:	66 90                	xchg   %ax,%ax
f010145e:	66 90                	xchg   %ax,%ax

f0101460 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0101460:	55                   	push   %ebp
f0101461:	89 e5                	mov    %esp,%ebp
f0101463:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0101466:	b8 00 00 00 00       	mov    $0x0,%eax
f010146b:	eb 03                	jmp    f0101470 <strlen+0x10>
		n++;
f010146d:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f0101470:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0101474:	75 f7                	jne    f010146d <strlen+0xd>
		n++;
	return n;
}
f0101476:	5d                   	pop    %ebp
f0101477:	c3                   	ret    

f0101478 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0101478:	55                   	push   %ebp
f0101479:	89 e5                	mov    %esp,%ebp
f010147b:	8b 4d 08             	mov    0x8(%ebp),%ecx
f010147e:	8b 55 0c             	mov    0xc(%ebp),%edx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0101481:	b8 00 00 00 00       	mov    $0x0,%eax
f0101486:	eb 03                	jmp    f010148b <strnlen+0x13>
		n++;
f0101488:	83 c0 01             	add    $0x1,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010148b:	39 d0                	cmp    %edx,%eax
f010148d:	74 06                	je     f0101495 <strnlen+0x1d>
f010148f:	80 3c 01 00          	cmpb   $0x0,(%ecx,%eax,1)
f0101493:	75 f3                	jne    f0101488 <strnlen+0x10>
		n++;
	return n;
}
f0101495:	5d                   	pop    %ebp
f0101496:	c3                   	ret    

f0101497 <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f0101497:	55                   	push   %ebp
f0101498:	89 e5                	mov    %esp,%ebp
f010149a:	53                   	push   %ebx
f010149b:	8b 45 08             	mov    0x8(%ebp),%eax
f010149e:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f01014a1:	89 c2                	mov    %eax,%edx
f01014a3:	83 c2 01             	add    $0x1,%edx
f01014a6:	83 c1 01             	add    $0x1,%ecx
f01014a9:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f01014ad:	88 5a ff             	mov    %bl,-0x1(%edx)
f01014b0:	84 db                	test   %bl,%bl
f01014b2:	75 ef                	jne    f01014a3 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f01014b4:	5b                   	pop    %ebx
f01014b5:	5d                   	pop    %ebp
f01014b6:	c3                   	ret    

f01014b7 <strcat>:

char *
strcat(char *dst, const char *src)
{
f01014b7:	55                   	push   %ebp
f01014b8:	89 e5                	mov    %esp,%ebp
f01014ba:	53                   	push   %ebx
f01014bb:	83 ec 08             	sub    $0x8,%esp
f01014be:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f01014c1:	89 1c 24             	mov    %ebx,(%esp)
f01014c4:	e8 97 ff ff ff       	call   f0101460 <strlen>
	strcpy(dst + len, src);
f01014c9:	8b 55 0c             	mov    0xc(%ebp),%edx
f01014cc:	89 54 24 04          	mov    %edx,0x4(%esp)
f01014d0:	01 d8                	add    %ebx,%eax
f01014d2:	89 04 24             	mov    %eax,(%esp)
f01014d5:	e8 bd ff ff ff       	call   f0101497 <strcpy>
	return dst;
}
f01014da:	89 d8                	mov    %ebx,%eax
f01014dc:	83 c4 08             	add    $0x8,%esp
f01014df:	5b                   	pop    %ebx
f01014e0:	5d                   	pop    %ebp
f01014e1:	c3                   	ret    

f01014e2 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f01014e2:	55                   	push   %ebp
f01014e3:	89 e5                	mov    %esp,%ebp
f01014e5:	56                   	push   %esi
f01014e6:	53                   	push   %ebx
f01014e7:	8b 75 08             	mov    0x8(%ebp),%esi
f01014ea:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01014ed:	89 f3                	mov    %esi,%ebx
f01014ef:	03 5d 10             	add    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f01014f2:	89 f2                	mov    %esi,%edx
f01014f4:	eb 0f                	jmp    f0101505 <strncpy+0x23>
		*dst++ = *src;
f01014f6:	83 c2 01             	add    $0x1,%edx
f01014f9:	0f b6 01             	movzbl (%ecx),%eax
f01014fc:	88 42 ff             	mov    %al,-0x1(%edx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f01014ff:	80 39 01             	cmpb   $0x1,(%ecx)
f0101502:	83 d9 ff             	sbb    $0xffffffff,%ecx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0101505:	39 da                	cmp    %ebx,%edx
f0101507:	75 ed                	jne    f01014f6 <strncpy+0x14>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f0101509:	89 f0                	mov    %esi,%eax
f010150b:	5b                   	pop    %ebx
f010150c:	5e                   	pop    %esi
f010150d:	5d                   	pop    %ebp
f010150e:	c3                   	ret    

f010150f <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f010150f:	55                   	push   %ebp
f0101510:	89 e5                	mov    %esp,%ebp
f0101512:	56                   	push   %esi
f0101513:	53                   	push   %ebx
f0101514:	8b 75 08             	mov    0x8(%ebp),%esi
f0101517:	8b 55 0c             	mov    0xc(%ebp),%edx
f010151a:	8b 4d 10             	mov    0x10(%ebp),%ecx
f010151d:	89 f0                	mov    %esi,%eax
f010151f:	8d 5c 0e ff          	lea    -0x1(%esi,%ecx,1),%ebx
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0101523:	85 c9                	test   %ecx,%ecx
f0101525:	75 0b                	jne    f0101532 <strlcpy+0x23>
f0101527:	eb 1d                	jmp    f0101546 <strlcpy+0x37>
		while (--size > 0 && *src != '\0')
			*dst++ = *src++;
f0101529:	83 c0 01             	add    $0x1,%eax
f010152c:	83 c2 01             	add    $0x1,%edx
f010152f:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0101532:	39 d8                	cmp    %ebx,%eax
f0101534:	74 0b                	je     f0101541 <strlcpy+0x32>
f0101536:	0f b6 0a             	movzbl (%edx),%ecx
f0101539:	84 c9                	test   %cl,%cl
f010153b:	75 ec                	jne    f0101529 <strlcpy+0x1a>
f010153d:	89 c2                	mov    %eax,%edx
f010153f:	eb 02                	jmp    f0101543 <strlcpy+0x34>
f0101541:	89 c2                	mov    %eax,%edx
			*dst++ = *src++;
		*dst = '\0';
f0101543:	c6 02 00             	movb   $0x0,(%edx)
	}
	return dst - dst_in;
f0101546:	29 f0                	sub    %esi,%eax
}
f0101548:	5b                   	pop    %ebx
f0101549:	5e                   	pop    %esi
f010154a:	5d                   	pop    %ebp
f010154b:	c3                   	ret    

f010154c <strcmp>:

int
strcmp(const char *p, const char *q)
{
f010154c:	55                   	push   %ebp
f010154d:	89 e5                	mov    %esp,%ebp
f010154f:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0101552:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f0101555:	eb 06                	jmp    f010155d <strcmp+0x11>
		p++, q++;
f0101557:	83 c1 01             	add    $0x1,%ecx
f010155a:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f010155d:	0f b6 01             	movzbl (%ecx),%eax
f0101560:	84 c0                	test   %al,%al
f0101562:	74 04                	je     f0101568 <strcmp+0x1c>
f0101564:	3a 02                	cmp    (%edx),%al
f0101566:	74 ef                	je     f0101557 <strcmp+0xb>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f0101568:	0f b6 c0             	movzbl %al,%eax
f010156b:	0f b6 12             	movzbl (%edx),%edx
f010156e:	29 d0                	sub    %edx,%eax
}
f0101570:	5d                   	pop    %ebp
f0101571:	c3                   	ret    

f0101572 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0101572:	55                   	push   %ebp
f0101573:	89 e5                	mov    %esp,%ebp
f0101575:	53                   	push   %ebx
f0101576:	8b 45 08             	mov    0x8(%ebp),%eax
f0101579:	8b 55 0c             	mov    0xc(%ebp),%edx
f010157c:	89 c3                	mov    %eax,%ebx
f010157e:	03 5d 10             	add    0x10(%ebp),%ebx
	while (n > 0 && *p && *p == *q)
f0101581:	eb 06                	jmp    f0101589 <strncmp+0x17>
		n--, p++, q++;
f0101583:	83 c0 01             	add    $0x1,%eax
f0101586:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f0101589:	39 d8                	cmp    %ebx,%eax
f010158b:	74 15                	je     f01015a2 <strncmp+0x30>
f010158d:	0f b6 08             	movzbl (%eax),%ecx
f0101590:	84 c9                	test   %cl,%cl
f0101592:	74 04                	je     f0101598 <strncmp+0x26>
f0101594:	3a 0a                	cmp    (%edx),%cl
f0101596:	74 eb                	je     f0101583 <strncmp+0x11>
		n--, p++, q++;
	if (n == 0)
		return 0;
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f0101598:	0f b6 00             	movzbl (%eax),%eax
f010159b:	0f b6 12             	movzbl (%edx),%edx
f010159e:	29 d0                	sub    %edx,%eax
f01015a0:	eb 05                	jmp    f01015a7 <strncmp+0x35>
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
		n--, p++, q++;
	if (n == 0)
		return 0;
f01015a2:	b8 00 00 00 00       	mov    $0x0,%eax
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
}
f01015a7:	5b                   	pop    %ebx
f01015a8:	5d                   	pop    %ebp
f01015a9:	c3                   	ret    

f01015aa <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f01015aa:	55                   	push   %ebp
f01015ab:	89 e5                	mov    %esp,%ebp
f01015ad:	8b 45 08             	mov    0x8(%ebp),%eax
f01015b0:	0f b6 4d 0c          	movzbl 0xc(%ebp),%ecx
	for (; *s; s++)
f01015b4:	eb 07                	jmp    f01015bd <strchr+0x13>
		if (*s == c)
f01015b6:	38 ca                	cmp    %cl,%dl
f01015b8:	74 0f                	je     f01015c9 <strchr+0x1f>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f01015ba:	83 c0 01             	add    $0x1,%eax
f01015bd:	0f b6 10             	movzbl (%eax),%edx
f01015c0:	84 d2                	test   %dl,%dl
f01015c2:	75 f2                	jne    f01015b6 <strchr+0xc>
		if (*s == c)
			return (char *) s;
	return 0;
f01015c4:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01015c9:	5d                   	pop    %ebp
f01015ca:	c3                   	ret    

f01015cb <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f01015cb:	55                   	push   %ebp
f01015cc:	89 e5                	mov    %esp,%ebp
f01015ce:	8b 45 08             	mov    0x8(%ebp),%eax
f01015d1:	0f b6 4d 0c          	movzbl 0xc(%ebp),%ecx
	for (; *s; s++)
f01015d5:	eb 07                	jmp    f01015de <strfind+0x13>
		if (*s == c)
f01015d7:	38 ca                	cmp    %cl,%dl
f01015d9:	74 0a                	je     f01015e5 <strfind+0x1a>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f01015db:	83 c0 01             	add    $0x1,%eax
f01015de:	0f b6 10             	movzbl (%eax),%edx
f01015e1:	84 d2                	test   %dl,%dl
f01015e3:	75 f2                	jne    f01015d7 <strfind+0xc>
		if (*s == c)
			break;
	return (char *) s;
}
f01015e5:	5d                   	pop    %ebp
f01015e6:	c3                   	ret    

f01015e7 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f01015e7:	55                   	push   %ebp
f01015e8:	89 e5                	mov    %esp,%ebp
f01015ea:	57                   	push   %edi
f01015eb:	56                   	push   %esi
f01015ec:	53                   	push   %ebx
f01015ed:	8b 7d 08             	mov    0x8(%ebp),%edi
f01015f0:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f01015f3:	85 c9                	test   %ecx,%ecx
f01015f5:	74 36                	je     f010162d <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f01015f7:	f7 c7 03 00 00 00    	test   $0x3,%edi
f01015fd:	75 28                	jne    f0101627 <memset+0x40>
f01015ff:	f6 c1 03             	test   $0x3,%cl
f0101602:	75 23                	jne    f0101627 <memset+0x40>
		c &= 0xFF;
f0101604:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f0101608:	89 d3                	mov    %edx,%ebx
f010160a:	c1 e3 08             	shl    $0x8,%ebx
f010160d:	89 d6                	mov    %edx,%esi
f010160f:	c1 e6 18             	shl    $0x18,%esi
f0101612:	89 d0                	mov    %edx,%eax
f0101614:	c1 e0 10             	shl    $0x10,%eax
f0101617:	09 f0                	or     %esi,%eax
f0101619:	09 c2                	or     %eax,%edx
f010161b:	89 d0                	mov    %edx,%eax
f010161d:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f010161f:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0101622:	fc                   	cld    
f0101623:	f3 ab                	rep stos %eax,%es:(%edi)
f0101625:	eb 06                	jmp    f010162d <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0101627:	8b 45 0c             	mov    0xc(%ebp),%eax
f010162a:	fc                   	cld    
f010162b:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f010162d:	89 f8                	mov    %edi,%eax
f010162f:	5b                   	pop    %ebx
f0101630:	5e                   	pop    %esi
f0101631:	5f                   	pop    %edi
f0101632:	5d                   	pop    %ebp
f0101633:	c3                   	ret    

f0101634 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0101634:	55                   	push   %ebp
f0101635:	89 e5                	mov    %esp,%ebp
f0101637:	57                   	push   %edi
f0101638:	56                   	push   %esi
f0101639:	8b 45 08             	mov    0x8(%ebp),%eax
f010163c:	8b 75 0c             	mov    0xc(%ebp),%esi
f010163f:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;

	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0101642:	39 c6                	cmp    %eax,%esi
f0101644:	73 35                	jae    f010167b <memmove+0x47>
f0101646:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0101649:	39 d0                	cmp    %edx,%eax
f010164b:	73 2e                	jae    f010167b <memmove+0x47>
		s += n;
		d += n;
f010164d:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0101650:	89 d6                	mov    %edx,%esi
f0101652:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0101654:	f7 c6 03 00 00 00    	test   $0x3,%esi
f010165a:	75 13                	jne    f010166f <memmove+0x3b>
f010165c:	f6 c1 03             	test   $0x3,%cl
f010165f:	75 0e                	jne    f010166f <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0101661:	83 ef 04             	sub    $0x4,%edi
f0101664:	8d 72 fc             	lea    -0x4(%edx),%esi
f0101667:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f010166a:	fd                   	std    
f010166b:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f010166d:	eb 09                	jmp    f0101678 <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f010166f:	83 ef 01             	sub    $0x1,%edi
f0101672:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0101675:	fd                   	std    
f0101676:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0101678:	fc                   	cld    
f0101679:	eb 1d                	jmp    f0101698 <memmove+0x64>
f010167b:	89 f2                	mov    %esi,%edx
f010167d:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f010167f:	f6 c2 03             	test   $0x3,%dl
f0101682:	75 0f                	jne    f0101693 <memmove+0x5f>
f0101684:	f6 c1 03             	test   $0x3,%cl
f0101687:	75 0a                	jne    f0101693 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f0101689:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f010168c:	89 c7                	mov    %eax,%edi
f010168e:	fc                   	cld    
f010168f:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0101691:	eb 05                	jmp    f0101698 <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0101693:	89 c7                	mov    %eax,%edi
f0101695:	fc                   	cld    
f0101696:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f0101698:	5e                   	pop    %esi
f0101699:	5f                   	pop    %edi
f010169a:	5d                   	pop    %ebp
f010169b:	c3                   	ret    

f010169c <memcpy>:
}
#endif

void *
memcpy(void *dst, const void *src, size_t n)
{
f010169c:	55                   	push   %ebp
f010169d:	89 e5                	mov    %esp,%ebp
f010169f:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f01016a2:	8b 45 10             	mov    0x10(%ebp),%eax
f01016a5:	89 44 24 08          	mov    %eax,0x8(%esp)
f01016a9:	8b 45 0c             	mov    0xc(%ebp),%eax
f01016ac:	89 44 24 04          	mov    %eax,0x4(%esp)
f01016b0:	8b 45 08             	mov    0x8(%ebp),%eax
f01016b3:	89 04 24             	mov    %eax,(%esp)
f01016b6:	e8 79 ff ff ff       	call   f0101634 <memmove>
}
f01016bb:	c9                   	leave  
f01016bc:	c3                   	ret    

f01016bd <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f01016bd:	55                   	push   %ebp
f01016be:	89 e5                	mov    %esp,%ebp
f01016c0:	56                   	push   %esi
f01016c1:	53                   	push   %ebx
f01016c2:	8b 55 08             	mov    0x8(%ebp),%edx
f01016c5:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01016c8:	89 d6                	mov    %edx,%esi
f01016ca:	03 75 10             	add    0x10(%ebp),%esi
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01016cd:	eb 1a                	jmp    f01016e9 <memcmp+0x2c>
		if (*s1 != *s2)
f01016cf:	0f b6 02             	movzbl (%edx),%eax
f01016d2:	0f b6 19             	movzbl (%ecx),%ebx
f01016d5:	38 d8                	cmp    %bl,%al
f01016d7:	74 0a                	je     f01016e3 <memcmp+0x26>
			return (int) *s1 - (int) *s2;
f01016d9:	0f b6 c0             	movzbl %al,%eax
f01016dc:	0f b6 db             	movzbl %bl,%ebx
f01016df:	29 d8                	sub    %ebx,%eax
f01016e1:	eb 0f                	jmp    f01016f2 <memcmp+0x35>
		s1++, s2++;
f01016e3:	83 c2 01             	add    $0x1,%edx
f01016e6:	83 c1 01             	add    $0x1,%ecx
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01016e9:	39 f2                	cmp    %esi,%edx
f01016eb:	75 e2                	jne    f01016cf <memcmp+0x12>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f01016ed:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01016f2:	5b                   	pop    %ebx
f01016f3:	5e                   	pop    %esi
f01016f4:	5d                   	pop    %ebp
f01016f5:	c3                   	ret    

f01016f6 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f01016f6:	55                   	push   %ebp
f01016f7:	89 e5                	mov    %esp,%ebp
f01016f9:	8b 45 08             	mov    0x8(%ebp),%eax
f01016fc:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	const void *ends = (const char *) s + n;
f01016ff:	89 c2                	mov    %eax,%edx
f0101701:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0101704:	eb 07                	jmp    f010170d <memfind+0x17>
		if (*(const unsigned char *) s == (unsigned char) c)
f0101706:	38 08                	cmp    %cl,(%eax)
f0101708:	74 07                	je     f0101711 <memfind+0x1b>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f010170a:	83 c0 01             	add    $0x1,%eax
f010170d:	39 d0                	cmp    %edx,%eax
f010170f:	72 f5                	jb     f0101706 <memfind+0x10>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f0101711:	5d                   	pop    %ebp
f0101712:	c3                   	ret    

f0101713 <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f0101713:	55                   	push   %ebp
f0101714:	89 e5                	mov    %esp,%ebp
f0101716:	57                   	push   %edi
f0101717:	56                   	push   %esi
f0101718:	53                   	push   %ebx
f0101719:	8b 55 08             	mov    0x8(%ebp),%edx
f010171c:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010171f:	eb 03                	jmp    f0101724 <strtol+0x11>
		s++;
f0101721:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0101724:	0f b6 0a             	movzbl (%edx),%ecx
f0101727:	80 f9 09             	cmp    $0x9,%cl
f010172a:	74 f5                	je     f0101721 <strtol+0xe>
f010172c:	80 f9 20             	cmp    $0x20,%cl
f010172f:	74 f0                	je     f0101721 <strtol+0xe>
		s++;

	// plus/minus sign
	if (*s == '+')
f0101731:	80 f9 2b             	cmp    $0x2b,%cl
f0101734:	75 0a                	jne    f0101740 <strtol+0x2d>
		s++;
f0101736:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f0101739:	bf 00 00 00 00       	mov    $0x0,%edi
f010173e:	eb 11                	jmp    f0101751 <strtol+0x3e>
f0101740:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f0101745:	80 f9 2d             	cmp    $0x2d,%cl
f0101748:	75 07                	jne    f0101751 <strtol+0x3e>
		s++, neg = 1;
f010174a:	8d 52 01             	lea    0x1(%edx),%edx
f010174d:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0101751:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f0101756:	75 15                	jne    f010176d <strtol+0x5a>
f0101758:	80 3a 30             	cmpb   $0x30,(%edx)
f010175b:	75 10                	jne    f010176d <strtol+0x5a>
f010175d:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0101761:	75 0a                	jne    f010176d <strtol+0x5a>
		s += 2, base = 16;
f0101763:	83 c2 02             	add    $0x2,%edx
f0101766:	b8 10 00 00 00       	mov    $0x10,%eax
f010176b:	eb 10                	jmp    f010177d <strtol+0x6a>
	else if (base == 0 && s[0] == '0')
f010176d:	85 c0                	test   %eax,%eax
f010176f:	75 0c                	jne    f010177d <strtol+0x6a>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0101771:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0101773:	80 3a 30             	cmpb   $0x30,(%edx)
f0101776:	75 05                	jne    f010177d <strtol+0x6a>
		s++, base = 8;
f0101778:	83 c2 01             	add    $0x1,%edx
f010177b:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f010177d:	bb 00 00 00 00       	mov    $0x0,%ebx
f0101782:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f0101785:	0f b6 0a             	movzbl (%edx),%ecx
f0101788:	8d 71 d0             	lea    -0x30(%ecx),%esi
f010178b:	89 f0                	mov    %esi,%eax
f010178d:	3c 09                	cmp    $0x9,%al
f010178f:	77 08                	ja     f0101799 <strtol+0x86>
			dig = *s - '0';
f0101791:	0f be c9             	movsbl %cl,%ecx
f0101794:	83 e9 30             	sub    $0x30,%ecx
f0101797:	eb 20                	jmp    f01017b9 <strtol+0xa6>
		else if (*s >= 'a' && *s <= 'z')
f0101799:	8d 71 9f             	lea    -0x61(%ecx),%esi
f010179c:	89 f0                	mov    %esi,%eax
f010179e:	3c 19                	cmp    $0x19,%al
f01017a0:	77 08                	ja     f01017aa <strtol+0x97>
			dig = *s - 'a' + 10;
f01017a2:	0f be c9             	movsbl %cl,%ecx
f01017a5:	83 e9 57             	sub    $0x57,%ecx
f01017a8:	eb 0f                	jmp    f01017b9 <strtol+0xa6>
		else if (*s >= 'A' && *s <= 'Z')
f01017aa:	8d 71 bf             	lea    -0x41(%ecx),%esi
f01017ad:	89 f0                	mov    %esi,%eax
f01017af:	3c 19                	cmp    $0x19,%al
f01017b1:	77 16                	ja     f01017c9 <strtol+0xb6>
			dig = *s - 'A' + 10;
f01017b3:	0f be c9             	movsbl %cl,%ecx
f01017b6:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f01017b9:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f01017bc:	7d 0f                	jge    f01017cd <strtol+0xba>
			break;
		s++, val = (val * base) + dig;
f01017be:	83 c2 01             	add    $0x1,%edx
f01017c1:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f01017c5:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f01017c7:	eb bc                	jmp    f0101785 <strtol+0x72>
f01017c9:	89 d8                	mov    %ebx,%eax
f01017cb:	eb 02                	jmp    f01017cf <strtol+0xbc>
f01017cd:	89 d8                	mov    %ebx,%eax

	if (endptr)
f01017cf:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f01017d3:	74 05                	je     f01017da <strtol+0xc7>
		*endptr = (char *) s;
f01017d5:	8b 75 0c             	mov    0xc(%ebp),%esi
f01017d8:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f01017da:	f7 d8                	neg    %eax
f01017dc:	85 ff                	test   %edi,%edi
f01017de:	0f 44 c3             	cmove  %ebx,%eax
}
f01017e1:	5b                   	pop    %ebx
f01017e2:	5e                   	pop    %esi
f01017e3:	5f                   	pop    %edi
f01017e4:	5d                   	pop    %ebp
f01017e5:	c3                   	ret    
f01017e6:	66 90                	xchg   %ax,%ax
f01017e8:	66 90                	xchg   %ax,%ax
f01017ea:	66 90                	xchg   %ax,%ax
f01017ec:	66 90                	xchg   %ax,%ax
f01017ee:	66 90                	xchg   %ax,%ax

f01017f0 <__udivdi3>:
f01017f0:	55                   	push   %ebp
f01017f1:	57                   	push   %edi
f01017f2:	56                   	push   %esi
f01017f3:	83 ec 0c             	sub    $0xc,%esp
f01017f6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01017fa:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f01017fe:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f0101802:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0101806:	85 c0                	test   %eax,%eax
f0101808:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010180c:	89 ea                	mov    %ebp,%edx
f010180e:	89 0c 24             	mov    %ecx,(%esp)
f0101811:	75 2d                	jne    f0101840 <__udivdi3+0x50>
f0101813:	39 e9                	cmp    %ebp,%ecx
f0101815:	77 61                	ja     f0101878 <__udivdi3+0x88>
f0101817:	85 c9                	test   %ecx,%ecx
f0101819:	89 ce                	mov    %ecx,%esi
f010181b:	75 0b                	jne    f0101828 <__udivdi3+0x38>
f010181d:	b8 01 00 00 00       	mov    $0x1,%eax
f0101822:	31 d2                	xor    %edx,%edx
f0101824:	f7 f1                	div    %ecx
f0101826:	89 c6                	mov    %eax,%esi
f0101828:	31 d2                	xor    %edx,%edx
f010182a:	89 e8                	mov    %ebp,%eax
f010182c:	f7 f6                	div    %esi
f010182e:	89 c5                	mov    %eax,%ebp
f0101830:	89 f8                	mov    %edi,%eax
f0101832:	f7 f6                	div    %esi
f0101834:	89 ea                	mov    %ebp,%edx
f0101836:	83 c4 0c             	add    $0xc,%esp
f0101839:	5e                   	pop    %esi
f010183a:	5f                   	pop    %edi
f010183b:	5d                   	pop    %ebp
f010183c:	c3                   	ret    
f010183d:	8d 76 00             	lea    0x0(%esi),%esi
f0101840:	39 e8                	cmp    %ebp,%eax
f0101842:	77 24                	ja     f0101868 <__udivdi3+0x78>
f0101844:	0f bd e8             	bsr    %eax,%ebp
f0101847:	83 f5 1f             	xor    $0x1f,%ebp
f010184a:	75 3c                	jne    f0101888 <__udivdi3+0x98>
f010184c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0101850:	39 34 24             	cmp    %esi,(%esp)
f0101853:	0f 86 9f 00 00 00    	jbe    f01018f8 <__udivdi3+0x108>
f0101859:	39 d0                	cmp    %edx,%eax
f010185b:	0f 82 97 00 00 00    	jb     f01018f8 <__udivdi3+0x108>
f0101861:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101868:	31 d2                	xor    %edx,%edx
f010186a:	31 c0                	xor    %eax,%eax
f010186c:	83 c4 0c             	add    $0xc,%esp
f010186f:	5e                   	pop    %esi
f0101870:	5f                   	pop    %edi
f0101871:	5d                   	pop    %ebp
f0101872:	c3                   	ret    
f0101873:	90                   	nop
f0101874:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101878:	89 f8                	mov    %edi,%eax
f010187a:	f7 f1                	div    %ecx
f010187c:	31 d2                	xor    %edx,%edx
f010187e:	83 c4 0c             	add    $0xc,%esp
f0101881:	5e                   	pop    %esi
f0101882:	5f                   	pop    %edi
f0101883:	5d                   	pop    %ebp
f0101884:	c3                   	ret    
f0101885:	8d 76 00             	lea    0x0(%esi),%esi
f0101888:	89 e9                	mov    %ebp,%ecx
f010188a:	8b 3c 24             	mov    (%esp),%edi
f010188d:	d3 e0                	shl    %cl,%eax
f010188f:	89 c6                	mov    %eax,%esi
f0101891:	b8 20 00 00 00       	mov    $0x20,%eax
f0101896:	29 e8                	sub    %ebp,%eax
f0101898:	89 c1                	mov    %eax,%ecx
f010189a:	d3 ef                	shr    %cl,%edi
f010189c:	89 e9                	mov    %ebp,%ecx
f010189e:	89 7c 24 08          	mov    %edi,0x8(%esp)
f01018a2:	8b 3c 24             	mov    (%esp),%edi
f01018a5:	09 74 24 08          	or     %esi,0x8(%esp)
f01018a9:	89 d6                	mov    %edx,%esi
f01018ab:	d3 e7                	shl    %cl,%edi
f01018ad:	89 c1                	mov    %eax,%ecx
f01018af:	89 3c 24             	mov    %edi,(%esp)
f01018b2:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01018b6:	d3 ee                	shr    %cl,%esi
f01018b8:	89 e9                	mov    %ebp,%ecx
f01018ba:	d3 e2                	shl    %cl,%edx
f01018bc:	89 c1                	mov    %eax,%ecx
f01018be:	d3 ef                	shr    %cl,%edi
f01018c0:	09 d7                	or     %edx,%edi
f01018c2:	89 f2                	mov    %esi,%edx
f01018c4:	89 f8                	mov    %edi,%eax
f01018c6:	f7 74 24 08          	divl   0x8(%esp)
f01018ca:	89 d6                	mov    %edx,%esi
f01018cc:	89 c7                	mov    %eax,%edi
f01018ce:	f7 24 24             	mull   (%esp)
f01018d1:	39 d6                	cmp    %edx,%esi
f01018d3:	89 14 24             	mov    %edx,(%esp)
f01018d6:	72 30                	jb     f0101908 <__udivdi3+0x118>
f01018d8:	8b 54 24 04          	mov    0x4(%esp),%edx
f01018dc:	89 e9                	mov    %ebp,%ecx
f01018de:	d3 e2                	shl    %cl,%edx
f01018e0:	39 c2                	cmp    %eax,%edx
f01018e2:	73 05                	jae    f01018e9 <__udivdi3+0xf9>
f01018e4:	3b 34 24             	cmp    (%esp),%esi
f01018e7:	74 1f                	je     f0101908 <__udivdi3+0x118>
f01018e9:	89 f8                	mov    %edi,%eax
f01018eb:	31 d2                	xor    %edx,%edx
f01018ed:	e9 7a ff ff ff       	jmp    f010186c <__udivdi3+0x7c>
f01018f2:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f01018f8:	31 d2                	xor    %edx,%edx
f01018fa:	b8 01 00 00 00       	mov    $0x1,%eax
f01018ff:	e9 68 ff ff ff       	jmp    f010186c <__udivdi3+0x7c>
f0101904:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101908:	8d 47 ff             	lea    -0x1(%edi),%eax
f010190b:	31 d2                	xor    %edx,%edx
f010190d:	83 c4 0c             	add    $0xc,%esp
f0101910:	5e                   	pop    %esi
f0101911:	5f                   	pop    %edi
f0101912:	5d                   	pop    %ebp
f0101913:	c3                   	ret    
f0101914:	66 90                	xchg   %ax,%ax
f0101916:	66 90                	xchg   %ax,%ax
f0101918:	66 90                	xchg   %ax,%ax
f010191a:	66 90                	xchg   %ax,%ax
f010191c:	66 90                	xchg   %ax,%ax
f010191e:	66 90                	xchg   %ax,%ax

f0101920 <__umoddi3>:
f0101920:	55                   	push   %ebp
f0101921:	57                   	push   %edi
f0101922:	56                   	push   %esi
f0101923:	83 ec 14             	sub    $0x14,%esp
f0101926:	8b 44 24 28          	mov    0x28(%esp),%eax
f010192a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f010192e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0101932:	89 c7                	mov    %eax,%edi
f0101934:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101938:	8b 44 24 30          	mov    0x30(%esp),%eax
f010193c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0101940:	89 34 24             	mov    %esi,(%esp)
f0101943:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0101947:	85 c0                	test   %eax,%eax
f0101949:	89 c2                	mov    %eax,%edx
f010194b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f010194f:	75 17                	jne    f0101968 <__umoddi3+0x48>
f0101951:	39 fe                	cmp    %edi,%esi
f0101953:	76 4b                	jbe    f01019a0 <__umoddi3+0x80>
f0101955:	89 c8                	mov    %ecx,%eax
f0101957:	89 fa                	mov    %edi,%edx
f0101959:	f7 f6                	div    %esi
f010195b:	89 d0                	mov    %edx,%eax
f010195d:	31 d2                	xor    %edx,%edx
f010195f:	83 c4 14             	add    $0x14,%esp
f0101962:	5e                   	pop    %esi
f0101963:	5f                   	pop    %edi
f0101964:	5d                   	pop    %ebp
f0101965:	c3                   	ret    
f0101966:	66 90                	xchg   %ax,%ax
f0101968:	39 f8                	cmp    %edi,%eax
f010196a:	77 54                	ja     f01019c0 <__umoddi3+0xa0>
f010196c:	0f bd e8             	bsr    %eax,%ebp
f010196f:	83 f5 1f             	xor    $0x1f,%ebp
f0101972:	75 5c                	jne    f01019d0 <__umoddi3+0xb0>
f0101974:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0101978:	39 3c 24             	cmp    %edi,(%esp)
f010197b:	0f 87 e7 00 00 00    	ja     f0101a68 <__umoddi3+0x148>
f0101981:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0101985:	29 f1                	sub    %esi,%ecx
f0101987:	19 c7                	sbb    %eax,%edi
f0101989:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f010198d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0101991:	8b 44 24 08          	mov    0x8(%esp),%eax
f0101995:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0101999:	83 c4 14             	add    $0x14,%esp
f010199c:	5e                   	pop    %esi
f010199d:	5f                   	pop    %edi
f010199e:	5d                   	pop    %ebp
f010199f:	c3                   	ret    
f01019a0:	85 f6                	test   %esi,%esi
f01019a2:	89 f5                	mov    %esi,%ebp
f01019a4:	75 0b                	jne    f01019b1 <__umoddi3+0x91>
f01019a6:	b8 01 00 00 00       	mov    $0x1,%eax
f01019ab:	31 d2                	xor    %edx,%edx
f01019ad:	f7 f6                	div    %esi
f01019af:	89 c5                	mov    %eax,%ebp
f01019b1:	8b 44 24 04          	mov    0x4(%esp),%eax
f01019b5:	31 d2                	xor    %edx,%edx
f01019b7:	f7 f5                	div    %ebp
f01019b9:	89 c8                	mov    %ecx,%eax
f01019bb:	f7 f5                	div    %ebp
f01019bd:	eb 9c                	jmp    f010195b <__umoddi3+0x3b>
f01019bf:	90                   	nop
f01019c0:	89 c8                	mov    %ecx,%eax
f01019c2:	89 fa                	mov    %edi,%edx
f01019c4:	83 c4 14             	add    $0x14,%esp
f01019c7:	5e                   	pop    %esi
f01019c8:	5f                   	pop    %edi
f01019c9:	5d                   	pop    %ebp
f01019ca:	c3                   	ret    
f01019cb:	90                   	nop
f01019cc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01019d0:	8b 04 24             	mov    (%esp),%eax
f01019d3:	be 20 00 00 00       	mov    $0x20,%esi
f01019d8:	89 e9                	mov    %ebp,%ecx
f01019da:	29 ee                	sub    %ebp,%esi
f01019dc:	d3 e2                	shl    %cl,%edx
f01019de:	89 f1                	mov    %esi,%ecx
f01019e0:	d3 e8                	shr    %cl,%eax
f01019e2:	89 e9                	mov    %ebp,%ecx
f01019e4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01019e8:	8b 04 24             	mov    (%esp),%eax
f01019eb:	09 54 24 04          	or     %edx,0x4(%esp)
f01019ef:	89 fa                	mov    %edi,%edx
f01019f1:	d3 e0                	shl    %cl,%eax
f01019f3:	89 f1                	mov    %esi,%ecx
f01019f5:	89 44 24 08          	mov    %eax,0x8(%esp)
f01019f9:	8b 44 24 10          	mov    0x10(%esp),%eax
f01019fd:	d3 ea                	shr    %cl,%edx
f01019ff:	89 e9                	mov    %ebp,%ecx
f0101a01:	d3 e7                	shl    %cl,%edi
f0101a03:	89 f1                	mov    %esi,%ecx
f0101a05:	d3 e8                	shr    %cl,%eax
f0101a07:	89 e9                	mov    %ebp,%ecx
f0101a09:	09 f8                	or     %edi,%eax
f0101a0b:	8b 7c 24 10          	mov    0x10(%esp),%edi
f0101a0f:	f7 74 24 04          	divl   0x4(%esp)
f0101a13:	d3 e7                	shl    %cl,%edi
f0101a15:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0101a19:	89 d7                	mov    %edx,%edi
f0101a1b:	f7 64 24 08          	mull   0x8(%esp)
f0101a1f:	39 d7                	cmp    %edx,%edi
f0101a21:	89 c1                	mov    %eax,%ecx
f0101a23:	89 14 24             	mov    %edx,(%esp)
f0101a26:	72 2c                	jb     f0101a54 <__umoddi3+0x134>
f0101a28:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f0101a2c:	72 22                	jb     f0101a50 <__umoddi3+0x130>
f0101a2e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0101a32:	29 c8                	sub    %ecx,%eax
f0101a34:	19 d7                	sbb    %edx,%edi
f0101a36:	89 e9                	mov    %ebp,%ecx
f0101a38:	89 fa                	mov    %edi,%edx
f0101a3a:	d3 e8                	shr    %cl,%eax
f0101a3c:	89 f1                	mov    %esi,%ecx
f0101a3e:	d3 e2                	shl    %cl,%edx
f0101a40:	89 e9                	mov    %ebp,%ecx
f0101a42:	d3 ef                	shr    %cl,%edi
f0101a44:	09 d0                	or     %edx,%eax
f0101a46:	89 fa                	mov    %edi,%edx
f0101a48:	83 c4 14             	add    $0x14,%esp
f0101a4b:	5e                   	pop    %esi
f0101a4c:	5f                   	pop    %edi
f0101a4d:	5d                   	pop    %ebp
f0101a4e:	c3                   	ret    
f0101a4f:	90                   	nop
f0101a50:	39 d7                	cmp    %edx,%edi
f0101a52:	75 da                	jne    f0101a2e <__umoddi3+0x10e>
f0101a54:	8b 14 24             	mov    (%esp),%edx
f0101a57:	89 c1                	mov    %eax,%ecx
f0101a59:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f0101a5d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0101a61:	eb cb                	jmp    f0101a2e <__umoddi3+0x10e>
f0101a63:	90                   	nop
f0101a64:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101a68:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f0101a6c:	0f 82 0f ff ff ff    	jb     f0101981 <__umoddi3+0x61>
f0101a72:	e9 1a ff ff ff       	jmp    f0101991 <__umoddi3+0x71>
