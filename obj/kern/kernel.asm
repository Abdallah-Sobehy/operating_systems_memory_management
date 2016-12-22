
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
f0100015:	b8 00 10 11 00       	mov    $0x111000,%eax
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
f0100034:	bc 00 10 11 f0       	mov    $0xf0111000,%esp

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
f0100046:	b8 70 39 11 f0       	mov    $0xf0113970,%eax
f010004b:	2d 00 33 11 f0       	sub    $0xf0113300,%eax
f0100050:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100054:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010005b:	00 
f010005c:	c7 04 24 00 33 11 f0 	movl   $0xf0113300,(%esp)
f0100063:	e8 8f 17 00 00       	call   f01017f7 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f0100068:	e8 a2 04 00 00       	call   f010050f <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f010006d:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f0100074:	00 
f0100075:	c7 04 24 a0 1c 10 f0 	movl   $0xf0101ca0,(%esp)
f010007c:	e8 78 0c 00 00       	call   f0100cf9 <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f0100081:	e8 ca 09 00 00       	call   f0100a50 <mem_init>

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
f010009f:	83 3d 60 39 11 f0 00 	cmpl   $0x0,0xf0113960
f01000a6:	75 3d                	jne    f01000e5 <_panic+0x51>
		goto dead;
	panicstr = fmt;
f01000a8:	89 35 60 39 11 f0    	mov    %esi,0xf0113960

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
f01000c1:	c7 04 24 bb 1c 10 f0 	movl   $0xf0101cbb,(%esp)
f01000c8:	e8 2c 0c 00 00       	call   f0100cf9 <cprintf>
	vcprintf(fmt, ap);
f01000cd:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01000d1:	89 34 24             	mov    %esi,(%esp)
f01000d4:	e8 ed 0b 00 00       	call   f0100cc6 <vcprintf>
	cprintf("\n");
f01000d9:	c7 04 24 97 22 10 f0 	movl   $0xf0102297,(%esp)
f01000e0:	e8 14 0c 00 00       	call   f0100cf9 <cprintf>
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
f010010b:	c7 04 24 d3 1c 10 f0 	movl   $0xf0101cd3,(%esp)
f0100112:	e8 e2 0b 00 00       	call   f0100cf9 <cprintf>
	vcprintf(fmt, ap);
f0100117:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010011b:	8b 45 10             	mov    0x10(%ebp),%eax
f010011e:	89 04 24             	mov    %eax,(%esp)
f0100121:	e8 a0 0b 00 00       	call   f0100cc6 <vcprintf>
	cprintf("\n");
f0100126:	c7 04 24 97 22 10 f0 	movl   $0xf0102297,(%esp)
f010012d:	e8 c7 0b 00 00       	call   f0100cf9 <cprintf>
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
f010016b:	a1 24 35 11 f0       	mov    0xf0113524,%eax
f0100170:	8d 48 01             	lea    0x1(%eax),%ecx
f0100173:	89 0d 24 35 11 f0    	mov    %ecx,0xf0113524
f0100179:	88 90 20 33 11 f0    	mov    %dl,-0xfeecce0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f010017f:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f0100185:	75 0a                	jne    f0100191 <cons_intr+0x35>
			cons.wpos = 0;
f0100187:	c7 05 24 35 11 f0 00 	movl   $0x0,0xf0113524
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
f01001bf:	83 0d 00 33 11 f0 40 	orl    $0x40,0xf0113300
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
f01001d7:	8b 0d 00 33 11 f0    	mov    0xf0113300,%ecx
f01001dd:	89 cb                	mov    %ecx,%ebx
f01001df:	83 e3 40             	and    $0x40,%ebx
f01001e2:	83 e0 7f             	and    $0x7f,%eax
f01001e5:	85 db                	test   %ebx,%ebx
f01001e7:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f01001ea:	0f b6 d2             	movzbl %dl,%edx
f01001ed:	0f b6 82 40 1e 10 f0 	movzbl -0xfefe1c0(%edx),%eax
f01001f4:	83 c8 40             	or     $0x40,%eax
f01001f7:	0f b6 c0             	movzbl %al,%eax
f01001fa:	f7 d0                	not    %eax
f01001fc:	21 c1                	and    %eax,%ecx
f01001fe:	89 0d 00 33 11 f0    	mov    %ecx,0xf0113300
		return 0;
f0100204:	b8 00 00 00 00       	mov    $0x0,%eax
f0100209:	e9 a3 00 00 00       	jmp    f01002b1 <kbd_proc_data+0x111>
	} else if (shift & E0ESC) {
f010020e:	8b 0d 00 33 11 f0    	mov    0xf0113300,%ecx
f0100214:	f6 c1 40             	test   $0x40,%cl
f0100217:	74 0e                	je     f0100227 <kbd_proc_data+0x87>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f0100219:	83 c8 80             	or     $0xffffff80,%eax
f010021c:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f010021e:	83 e1 bf             	and    $0xffffffbf,%ecx
f0100221:	89 0d 00 33 11 f0    	mov    %ecx,0xf0113300
	}

	shift |= shiftcode[data];
f0100227:	0f b6 d2             	movzbl %dl,%edx
f010022a:	0f b6 82 40 1e 10 f0 	movzbl -0xfefe1c0(%edx),%eax
f0100231:	0b 05 00 33 11 f0    	or     0xf0113300,%eax
	shift ^= togglecode[data];
f0100237:	0f b6 8a 40 1d 10 f0 	movzbl -0xfefe2c0(%edx),%ecx
f010023e:	31 c8                	xor    %ecx,%eax
f0100240:	a3 00 33 11 f0       	mov    %eax,0xf0113300

	c = charcode[shift & (CTL | SHIFT)][data];
f0100245:	89 c1                	mov    %eax,%ecx
f0100247:	83 e1 03             	and    $0x3,%ecx
f010024a:	8b 0c 8d 20 1d 10 f0 	mov    -0xfefe2e0(,%ecx,4),%ecx
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
f010028a:	c7 04 24 ed 1c 10 f0 	movl   $0xf0101ced,(%esp)
f0100291:	e8 63 0a 00 00       	call   f0100cf9 <cprintf>
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
f010036c:	0f b7 05 28 35 11 f0 	movzwl 0xf0113528,%eax
f0100373:	66 85 c0             	test   %ax,%ax
f0100376:	0f 84 e5 00 00 00    	je     f0100461 <cons_putc+0x1aa>
			crt_pos--;
f010037c:	83 e8 01             	sub    $0x1,%eax
f010037f:	66 a3 28 35 11 f0    	mov    %ax,0xf0113528
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100385:	0f b7 c0             	movzwl %ax,%eax
f0100388:	66 81 e7 00 ff       	and    $0xff00,%di
f010038d:	83 cf 20             	or     $0x20,%edi
f0100390:	8b 15 2c 35 11 f0    	mov    0xf011352c,%edx
f0100396:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f010039a:	eb 78                	jmp    f0100414 <cons_putc+0x15d>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f010039c:	66 83 05 28 35 11 f0 	addw   $0x50,0xf0113528
f01003a3:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f01003a4:	0f b7 05 28 35 11 f0 	movzwl 0xf0113528,%eax
f01003ab:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f01003b1:	c1 e8 16             	shr    $0x16,%eax
f01003b4:	8d 04 80             	lea    (%eax,%eax,4),%eax
f01003b7:	c1 e0 04             	shl    $0x4,%eax
f01003ba:	66 a3 28 35 11 f0    	mov    %ax,0xf0113528
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
f01003f6:	0f b7 05 28 35 11 f0 	movzwl 0xf0113528,%eax
f01003fd:	8d 50 01             	lea    0x1(%eax),%edx
f0100400:	66 89 15 28 35 11 f0 	mov    %dx,0xf0113528
f0100407:	0f b7 c0             	movzwl %ax,%eax
f010040a:	8b 15 2c 35 11 f0    	mov    0xf011352c,%edx
f0100410:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f0100414:	66 81 3d 28 35 11 f0 	cmpw   $0x7cf,0xf0113528
f010041b:	cf 07 
f010041d:	76 42                	jbe    f0100461 <cons_putc+0x1aa>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f010041f:	a1 2c 35 11 f0       	mov    0xf011352c,%eax
f0100424:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f010042b:	00 
f010042c:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100432:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100436:	89 04 24             	mov    %eax,(%esp)
f0100439:	e8 06 14 00 00       	call   f0101844 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f010043e:	8b 15 2c 35 11 f0    	mov    0xf011352c,%edx
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
f0100459:	66 83 2d 28 35 11 f0 	subw   $0x50,0xf0113528
f0100460:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100461:	8b 0d 30 35 11 f0    	mov    0xf0113530,%ecx
f0100467:	b8 0e 00 00 00       	mov    $0xe,%eax
f010046c:	89 ca                	mov    %ecx,%edx
f010046e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010046f:	0f b7 1d 28 35 11 f0 	movzwl 0xf0113528,%ebx
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
f0100497:	80 3d 34 35 11 f0 00 	cmpb   $0x0,0xf0113534
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
f01004d5:	a1 20 35 11 f0       	mov    0xf0113520,%eax
f01004da:	3b 05 24 35 11 f0    	cmp    0xf0113524,%eax
f01004e0:	74 26                	je     f0100508 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f01004e2:	8d 50 01             	lea    0x1(%eax),%edx
f01004e5:	89 15 20 35 11 f0    	mov    %edx,0xf0113520
f01004eb:	0f b6 88 20 33 11 f0 	movzbl -0xfeecce0(%eax),%ecx
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
f01004fc:	c7 05 20 35 11 f0 00 	movl   $0x0,0xf0113520
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
f0100535:	c7 05 30 35 11 f0 b4 	movl   $0x3b4,0xf0113530
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
f010054d:	c7 05 30 35 11 f0 d4 	movl   $0x3d4,0xf0113530
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
f010055c:	8b 0d 30 35 11 f0    	mov    0xf0113530,%ecx
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
f0100581:	89 3d 2c 35 11 f0    	mov    %edi,0xf011352c

	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f0100587:	0f b6 d8             	movzbl %al,%ebx
f010058a:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f010058c:	66 89 35 28 35 11 f0 	mov    %si,0xf0113528
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
f01005dd:	88 0d 34 35 11 f0    	mov    %cl,0xf0113534
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
f01005ed:	c7 04 24 f9 1c 10 f0 	movl   $0xf0101cf9,(%esp)
f01005f4:	e8 00 07 00 00       	call   f0100cf9 <cprintf>
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
f0100636:	c7 44 24 08 40 1f 10 	movl   $0xf0101f40,0x8(%esp)
f010063d:	f0 
f010063e:	c7 44 24 04 5e 1f 10 	movl   $0xf0101f5e,0x4(%esp)
f0100645:	f0 
f0100646:	c7 04 24 63 1f 10 f0 	movl   $0xf0101f63,(%esp)
f010064d:	e8 a7 06 00 00       	call   f0100cf9 <cprintf>
f0100652:	c7 44 24 08 cc 1f 10 	movl   $0xf0101fcc,0x8(%esp)
f0100659:	f0 
f010065a:	c7 44 24 04 6c 1f 10 	movl   $0xf0101f6c,0x4(%esp)
f0100661:	f0 
f0100662:	c7 04 24 63 1f 10 f0 	movl   $0xf0101f63,(%esp)
f0100669:	e8 8b 06 00 00       	call   f0100cf9 <cprintf>
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
f010067b:	c7 04 24 75 1f 10 f0 	movl   $0xf0101f75,(%esp)
f0100682:	e8 72 06 00 00       	call   f0100cf9 <cprintf>
	cprintf("  _start                  %08x (phys)\n", _start);
f0100687:	c7 44 24 04 0c 00 10 	movl   $0x10000c,0x4(%esp)
f010068e:	00 
f010068f:	c7 04 24 f4 1f 10 f0 	movl   $0xf0101ff4,(%esp)
f0100696:	e8 5e 06 00 00       	call   f0100cf9 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
f010069b:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f01006a2:	00 
f01006a3:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f01006aa:	f0 
f01006ab:	c7 04 24 1c 20 10 f0 	movl   $0xf010201c,(%esp)
f01006b2:	e8 42 06 00 00       	call   f0100cf9 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01006b7:	c7 44 24 08 87 1c 10 	movl   $0x101c87,0x8(%esp)
f01006be:	00 
f01006bf:	c7 44 24 04 87 1c 10 	movl   $0xf0101c87,0x4(%esp)
f01006c6:	f0 
f01006c7:	c7 04 24 40 20 10 f0 	movl   $0xf0102040,(%esp)
f01006ce:	e8 26 06 00 00       	call   f0100cf9 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f01006d3:	c7 44 24 08 00 33 11 	movl   $0x113300,0x8(%esp)
f01006da:	00 
f01006db:	c7 44 24 04 00 33 11 	movl   $0xf0113300,0x4(%esp)
f01006e2:	f0 
f01006e3:	c7 04 24 64 20 10 f0 	movl   $0xf0102064,(%esp)
f01006ea:	e8 0a 06 00 00       	call   f0100cf9 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f01006ef:	c7 44 24 08 70 39 11 	movl   $0x113970,0x8(%esp)
f01006f6:	00 
f01006f7:	c7 44 24 04 70 39 11 	movl   $0xf0113970,0x4(%esp)
f01006fe:	f0 
f01006ff:	c7 04 24 88 20 10 f0 	movl   $0xf0102088,(%esp)
f0100706:	e8 ee 05 00 00       	call   f0100cf9 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		ROUNDUP(end - entry, 1024) / 1024);
f010070b:	b8 6f 3d 11 f0       	mov    $0xf0113d6f,%eax
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
f010072c:	c7 04 24 ac 20 10 f0 	movl   $0xf01020ac,(%esp)
f0100733:	e8 c1 05 00 00       	call   f0100cf9 <cprintf>
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
f0100752:	c7 04 24 d8 20 10 f0 	movl   $0xf01020d8,(%esp)
f0100759:	e8 9b 05 00 00       	call   f0100cf9 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f010075e:	c7 04 24 fc 20 10 f0 	movl   $0xf01020fc,(%esp)
f0100765:	e8 8f 05 00 00       	call   f0100cf9 <cprintf>


	while (1) {
		buf = readline("K> ");
f010076a:	c7 04 24 8e 1f 10 f0 	movl   $0xf0101f8e,(%esp)
f0100771:	e8 2a 0e 00 00       	call   f01015a0 <readline>
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
f01007a2:	c7 04 24 92 1f 10 f0 	movl   $0xf0101f92,(%esp)
f01007a9:	e8 0c 10 00 00       	call   f01017ba <strchr>
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
f01007c4:	c7 04 24 97 1f 10 f0 	movl   $0xf0101f97,(%esp)
f01007cb:	e8 29 05 00 00       	call   f0100cf9 <cprintf>
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
f01007ec:	c7 04 24 92 1f 10 f0 	movl   $0xf0101f92,(%esp)
f01007f3:	e8 c2 0f 00 00       	call   f01017ba <strchr>
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
f010080e:	c7 44 24 04 5e 1f 10 	movl   $0xf0101f5e,0x4(%esp)
f0100815:	f0 
f0100816:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100819:	89 04 24             	mov    %eax,(%esp)
f010081c:	e8 3b 0f 00 00       	call   f010175c <strcmp>
f0100821:	85 c0                	test   %eax,%eax
f0100823:	74 1b                	je     f0100840 <monitor+0xf7>
f0100825:	c7 44 24 04 6c 1f 10 	movl   $0xf0101f6c,0x4(%esp)
f010082c:	f0 
f010082d:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100830:	89 04 24             	mov    %eax,(%esp)
f0100833:	e8 24 0f 00 00       	call   f010175c <strcmp>
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
f010085b:	ff 14 85 2c 21 10 f0 	call   *-0xfefded4(,%eax,4)


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
f0100872:	c7 04 24 b4 1f 10 f0 	movl   $0xf0101fb4,(%esp)
f0100879:	e8 7b 04 00 00       	call   f0100cf9 <cprintf>
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

f010088b <boot_alloc>:
	// Initialize nextfree if this is the first time.
	// 'end' is a magic symbol automatically generated by the linker,
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
f010088b:	83 3d 38 35 11 f0 00 	cmpl   $0x0,0xf0113538
f0100892:	75 11                	jne    f01008a5 <boot_alloc+0x1a>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100894:	ba 6f 49 11 f0       	mov    $0xf011496f,%edx
f0100899:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f010089f:	89 15 38 35 11 f0    	mov    %edx,0xf0113538
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	//else// if not the first time (next free already has a value)
	if(n==0)
f01008a5:	85 c0                	test   %eax,%eax
f01008a7:	75 06                	jne    f01008af <boot_alloc+0x24>
		return (void *)nextfree; // the result is the currently free place
f01008a9:	a1 38 35 11 f0       	mov    0xf0113538,%eax
			return result;
		}
	}
	//panic("boot_alloc: This function is not finished\n");
	//return NULL;
}
f01008ae:	c3                   	ret    
// If we're out of memory, boot_alloc should panic.
// This function may ONLY be used during initialization,
// before the page_free_list list has been set up.
static void *
boot_alloc(uint32_t n)
{
f01008af:	55                   	push   %ebp
f01008b0:	89 e5                	mov    %esp,%ebp
f01008b2:	53                   	push   %ebx
f01008b3:	83 ec 14             	sub    $0x14,%esp
	if(n==0)
		return (void *)nextfree; // the result is the currently free place
	else
	{
		// number of pages requested
		int numPagesRequested = ROUNDUP(n,PGSIZE)/PGSIZE;
f01008b6:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f01008bc:	89 d1                	mov    %edx,%ecx
f01008be:	c1 e9 0c             	shr    $0xc,%ecx
		// check if n exceeds memory panic
		//cprintf("%x,%x\n",PADDR(nextfree),numPagesRequested);
		if (npages<=(numPagesRequested + ((uint32_t)PADDR(nextfree)/PGSIZE)))
f01008c1:	8b 15 38 35 11 f0    	mov    0xf0113538,%edx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01008c7:	81 fa ff ff ff ef    	cmp    $0xefffffff,%edx
f01008cd:	77 20                	ja     f01008ef <boot_alloc+0x64>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01008cf:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01008d3:	c7 44 24 08 3c 21 10 	movl   $0xf010213c,0x8(%esp)
f01008da:	f0 
f01008db:	c7 44 24 04 71 00 00 	movl   $0x71,0x4(%esp)
f01008e2:	00 
f01008e3:	c7 04 24 80 22 10 f0 	movl   $0xf0102280,(%esp)
f01008ea:	e8 a5 f7 ff ff       	call   f0100094 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01008ef:	8d 9a 00 00 00 10    	lea    0x10000000(%edx),%ebx
f01008f5:	c1 eb 0c             	shr    $0xc,%ebx
f01008f8:	01 d9                	add    %ebx,%ecx
f01008fa:	3b 0d 64 39 11 f0    	cmp    0xf0113964,%ecx
f0100900:	72 1c                	jb     f010091e <boot_alloc+0x93>
		{
			panic("boot_alloc: size of requested memory for allocation exceeds memory size\n");
f0100902:	c7 44 24 08 60 21 10 	movl   $0xf0102160,0x8(%esp)
f0100909:	f0 
f010090a:	c7 44 24 04 73 00 00 	movl   $0x73,0x4(%esp)
f0100911:	00 
f0100912:	c7 04 24 80 22 10 f0 	movl   $0xf0102280,(%esp)
f0100919:	e8 76 f7 ff ff       	call   f0100094 <_panic>
			return NULL;
		}
		else
		{
			result = nextfree;
			nextfree = (char *)ROUNDUP(n + (uint32_t)nextfree, PGSIZE);
f010091e:	8d 84 02 ff 0f 00 00 	lea    0xfff(%edx,%eax,1),%eax
f0100925:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f010092a:	a3 38 35 11 f0       	mov    %eax,0xf0113538
			return result;
f010092f:	89 d0                	mov    %edx,%eax
		}
	}
	//panic("boot_alloc: This function is not finished\n");
	//return NULL;
}
f0100931:	83 c4 14             	add    $0x14,%esp
f0100934:	5b                   	pop    %ebx
f0100935:	5d                   	pop    %ebp
f0100936:	c3                   	ret    

f0100937 <nvram_read>:
// Detect machine's physical memory setup.
// --------------------------------------------------------------

static int
nvram_read(int r)
{
f0100937:	55                   	push   %ebp
f0100938:	89 e5                	mov    %esp,%ebp
f010093a:	56                   	push   %esi
f010093b:	53                   	push   %ebx
f010093c:	83 ec 10             	sub    $0x10,%esp
f010093f:	89 c3                	mov    %eax,%ebx
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0100941:	89 04 24             	mov    %eax,(%esp)
f0100944:	e8 40 03 00 00       	call   f0100c89 <mc146818_read>
f0100949:	89 c6                	mov    %eax,%esi
f010094b:	83 c3 01             	add    $0x1,%ebx
f010094e:	89 1c 24             	mov    %ebx,(%esp)
f0100951:	e8 33 03 00 00       	call   f0100c89 <mc146818_read>
f0100956:	c1 e0 08             	shl    $0x8,%eax
f0100959:	09 f0                	or     %esi,%eax
}
f010095b:	83 c4 10             	add    $0x10,%esp
f010095e:	5b                   	pop    %ebx
f010095f:	5e                   	pop    %esi
f0100960:	5d                   	pop    %ebp
f0100961:	c3                   	ret    

f0100962 <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0100962:	55                   	push   %ebp
f0100963:	89 e5                	mov    %esp,%ebp
f0100965:	56                   	push   %esi
f0100966:	53                   	push   %ebx
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages! [[what does this mean ?]]
	size_t i;
	// [[ Budy page will not be poiting to the first free space if the linked list gets updated!]]
	// 1)
	pages[0].pp_ref = 1; // in use
f0100967:	a1 6c 39 11 f0       	mov    0xf011396c,%eax
f010096c:	66 c7 40 04 01 00    	movw   $0x1,0x4(%eax)
	pages[0].pp_link = NULL;
f0100972:	c7 00 00 00 00 00    	movl   $0x0,(%eax)

	// 2)
	//cprintf("num of pages in base memory : %d\n", npages_basemem);
	for (i = 1; i < npages_basemem; i++) {
f0100978:	8b 35 40 35 11 f0    	mov    0xf0113540,%esi
f010097e:	8b 1d 3c 35 11 f0    	mov    0xf011353c,%ebx
f0100984:	b8 01 00 00 00       	mov    $0x1,%eax
f0100989:	eb 22                	jmp    f01009ad <page_init+0x4b>
f010098b:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
		pages[i].pp_ref = 0;
f0100992:	89 d1                	mov    %edx,%ecx
f0100994:	03 0d 6c 39 11 f0    	add    0xf011396c,%ecx
f010099a:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f01009a0:	89 19                	mov    %ebx,(%ecx)
	pages[0].pp_ref = 1; // in use
	pages[0].pp_link = NULL;

	// 2)
	//cprintf("num of pages in base memory : %d\n", npages_basemem);
	for (i = 1; i < npages_basemem; i++) {
f01009a2:	83 c0 01             	add    $0x1,%eax
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f01009a5:	89 d3                	mov    %edx,%ebx
f01009a7:	03 1d 6c 39 11 f0    	add    0xf011396c,%ebx
	pages[0].pp_ref = 1; // in use
	pages[0].pp_link = NULL;

	// 2)
	//cprintf("num of pages in base memory : %d\n", npages_basemem);
	for (i = 1; i < npages_basemem; i++) {
f01009ad:	39 f0                	cmp    %esi,%eax
f01009af:	72 da                	jb     f010098b <page_init+0x29>
f01009b1:	89 1d 3c 35 11 f0    	mov    %ebx,0xf011353c
f01009b7:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
		page_free_list = &pages[i];
	}
	// 3)
	// number of pages in I/O hole = (IOPHYSMEM, EXTPHYSMEM)/PGSIZE
	// [[ why not (MMIOLIM - MMIOBASE)/PGSIZE ]]
	for (int tmp = i ; i < tmp + (EXTPHYSMEM - IOPHYSMEM)/PGSIZE ; i++)
f01009be:	8d 58 60             	lea    0x60(%eax),%ebx
f01009c1:	eb 1a                	jmp    f01009dd <page_init+0x7b>
	{
		pages[i].pp_ref = 1;// busy [[ is there a way to gurantee it is always busy?]]
f01009c3:	89 d1                	mov    %edx,%ecx
f01009c5:	03 0d 6c 39 11 f0    	add    0xf011396c,%ecx
f01009cb:	66 c7 41 04 01 00    	movw   $0x1,0x4(%ecx)
		pages[i].pp_link = NULL; //[[ Do we need to point at next free in busy pages ? ]]
f01009d1:	c7 01 00 00 00 00    	movl   $0x0,(%ecx)
		page_free_list = &pages[i];
	}
	// 3)
	// number of pages in I/O hole = (IOPHYSMEM, EXTPHYSMEM)/PGSIZE
	// [[ why not (MMIOLIM - MMIOBASE)/PGSIZE ]]
	for (int tmp = i ; i < tmp + (EXTPHYSMEM - IOPHYSMEM)/PGSIZE ; i++)
f01009d7:	83 c0 01             	add    $0x1,%eax
f01009da:	83 c2 08             	add    $0x8,%edx
f01009dd:	39 d8                	cmp    %ebx,%eax
f01009df:	72 e2                	jb     f01009c3 <page_init+0x61>
f01009e1:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
		pages[i].pp_ref = 1;// busy [[ is there a way to gurantee it is always busy?]]
		pages[i].pp_link = NULL; //[[ Do we need to point at next free in busy pages ? ]]
	}
	//cprintf("%d , %d , %d\n", IOPHYSMEM, EXTPHYSMEM, (EXTPHYSMEM - IOPHYSMEM)/PGSIZE);
	// 4) [[ kernel reserved space is KSTKSIZE + KSTKGAP ??]]
	for (int tmp = i ; i < tmp + (KSTKSIZE + KSTKGAP)/PGSIZE ; i++)
f01009e8:	8d 58 10             	lea    0x10(%eax),%ebx
f01009eb:	eb 1a                	jmp    f0100a07 <page_init+0xa5>
	{
		pages[i].pp_ref = 1;// busy [[ is there a way to gurantee it is always busy?]]
f01009ed:	89 d1                	mov    %edx,%ecx
f01009ef:	03 0d 6c 39 11 f0    	add    0xf011396c,%ecx
f01009f5:	66 c7 41 04 01 00    	movw   $0x1,0x4(%ecx)
		pages[i].pp_link = NULL; //[[ Do we need to point at next free in busy pages ? ]]
f01009fb:	c7 01 00 00 00 00    	movl   $0x0,(%ecx)
		pages[i].pp_ref = 1;// busy [[ is there a way to gurantee it is always busy?]]
		pages[i].pp_link = NULL; //[[ Do we need to point at next free in busy pages ? ]]
	}
	//cprintf("%d , %d , %d\n", IOPHYSMEM, EXTPHYSMEM, (EXTPHYSMEM - IOPHYSMEM)/PGSIZE);
	// 4) [[ kernel reserved space is KSTKSIZE + KSTKGAP ??]]
	for (int tmp = i ; i < tmp + (KSTKSIZE + KSTKGAP)/PGSIZE ; i++)
f0100a01:	83 c0 01             	add    $0x1,%eax
f0100a04:	83 c2 08             	add    $0x8,%edx
f0100a07:	39 d8                	cmp    %ebx,%eax
f0100a09:	72 e2                	jb     f01009ed <page_init+0x8b>
f0100a0b:	89 c6                	mov    %eax,%esi
f0100a0d:	8b 1d 3c 35 11 f0    	mov    0xf011353c,%ebx
f0100a13:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
f0100a1a:	eb 1e                	jmp    f0100a3a <page_init+0xd8>
		pages[i].pp_link = NULL; //[[ Do we need to point at next free in busy pages ? ]]
	}
	// The rest of the memory is free: npages - the number of pages allocated so far
	for (int tmp = i ; i < npages - tmp ; i++)
	{
		pages[i].pp_ref = 0;
f0100a1c:	89 d1                	mov    %edx,%ecx
f0100a1e:	03 0d 6c 39 11 f0    	add    0xf011396c,%ecx
f0100a24:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0100a2a:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f0100a2c:	89 d3                	mov    %edx,%ebx
f0100a2e:	03 1d 6c 39 11 f0    	add    0xf011396c,%ebx
	{
		pages[i].pp_ref = 1;// busy [[ is there a way to gurantee it is always busy?]]
		pages[i].pp_link = NULL; //[[ Do we need to point at next free in busy pages ? ]]
	}
	// The rest of the memory is free: npages - the number of pages allocated so far
	for (int tmp = i ; i < npages - tmp ; i++)
f0100a34:	83 c0 01             	add    $0x1,%eax
f0100a37:	83 c2 08             	add    $0x8,%edx
f0100a3a:	8b 0d 64 39 11 f0    	mov    0xf0113964,%ecx
f0100a40:	29 f1                	sub    %esi,%ecx
f0100a42:	39 c8                	cmp    %ecx,%eax
f0100a44:	72 d6                	jb     f0100a1c <page_init+0xba>
f0100a46:	89 1d 3c 35 11 f0    	mov    %ebx,0xf011353c
	{
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
	}
}
f0100a4c:	5b                   	pop    %ebx
f0100a4d:	5e                   	pop    %esi
f0100a4e:	5d                   	pop    %ebp
f0100a4f:	c3                   	ret    

f0100a50 <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f0100a50:	55                   	push   %ebp
f0100a51:	89 e5                	mov    %esp,%ebp
f0100a53:	56                   	push   %esi
f0100a54:	53                   	push   %ebx
f0100a55:	83 ec 10             	sub    $0x10,%esp
{
	size_t basemem, extmem, ext16mem, totalmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	basemem = nvram_read(NVRAM_BASELO);
f0100a58:	b8 15 00 00 00       	mov    $0x15,%eax
f0100a5d:	e8 d5 fe ff ff       	call   f0100937 <nvram_read>
f0100a62:	89 c3                	mov    %eax,%ebx
	extmem = nvram_read(NVRAM_EXTLO);
f0100a64:	b8 17 00 00 00       	mov    $0x17,%eax
f0100a69:	e8 c9 fe ff ff       	call   f0100937 <nvram_read>
f0100a6e:	89 c6                	mov    %eax,%esi
	ext16mem = nvram_read(NVRAM_EXT16LO) * 64;
f0100a70:	b8 34 00 00 00       	mov    $0x34,%eax
f0100a75:	e8 bd fe ff ff       	call   f0100937 <nvram_read>
f0100a7a:	c1 e0 06             	shl    $0x6,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (ext16mem)
f0100a7d:	85 c0                	test   %eax,%eax
f0100a7f:	74 07                	je     f0100a88 <mem_init+0x38>
		totalmem = 16 * 1024 + ext16mem;
f0100a81:	05 00 40 00 00       	add    $0x4000,%eax
f0100a86:	eb 0b                	jmp    f0100a93 <mem_init+0x43>
	else if (extmem)
		totalmem = 1 * 1024 + extmem;
f0100a88:	8d 86 00 04 00 00    	lea    0x400(%esi),%eax
f0100a8e:	85 f6                	test   %esi,%esi
f0100a90:	0f 44 c3             	cmove  %ebx,%eax
	else
		totalmem = basemem;

	npages = totalmem / (PGSIZE / 1024);
f0100a93:	89 c2                	mov    %eax,%edx
f0100a95:	c1 ea 02             	shr    $0x2,%edx
f0100a98:	89 15 64 39 11 f0    	mov    %edx,0xf0113964
	npages_basemem = basemem / (PGSIZE / 1024);
f0100a9e:	89 da                	mov    %ebx,%edx
f0100aa0:	c1 ea 02             	shr    $0x2,%edx
f0100aa3:	89 15 40 35 11 f0    	mov    %edx,0xf0113540

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0100aa9:	89 c2                	mov    %eax,%edx
f0100aab:	29 da                	sub    %ebx,%edx
f0100aad:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100ab1:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0100ab5:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100ab9:	c7 04 24 ac 21 10 f0 	movl   $0xf01021ac,(%esp)
f0100ac0:	e8 34 02 00 00       	call   f0100cf9 <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);
f0100ac5:	b8 00 10 00 00       	mov    $0x1000,%eax
f0100aca:	e8 bc fd ff ff       	call   f010088b <boot_alloc>
f0100acf:	a3 68 39 11 f0       	mov    %eax,0xf0113968
	memset(kern_pgdir, 0, PGSIZE);
f0100ad4:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0100adb:	00 
f0100adc:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0100ae3:	00 
f0100ae4:	89 04 24             	mov    %eax,(%esp)
f0100ae7:	e8 0b 0d 00 00       	call   f01017f7 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following line.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f0100aec:	a1 68 39 11 f0       	mov    0xf0113968,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100af1:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0100af6:	77 20                	ja     f0100b18 <mem_init+0xc8>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0100af8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100afc:	c7 44 24 08 3c 21 10 	movl   $0xf010213c,0x8(%esp)
f0100b03:	f0 
f0100b04:	c7 44 24 04 a2 00 00 	movl   $0xa2,0x4(%esp)
f0100b0b:	00 
f0100b0c:	c7 04 24 80 22 10 f0 	movl   $0xf0102280,(%esp)
f0100b13:	e8 7c f5 ff ff       	call   f0100094 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0100b18:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f0100b1e:	83 ca 05             	or     $0x5,%edx
f0100b21:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct PageInfo in this
	// array.  'npages' is the number of physical pages in memory.  Use memset
	// to initialize all fields of each struct PageInfo to 0.
	// Your code goes here:
	pages = (struct PageInfo *) boot_alloc(npages*sizeof(struct PageInfo));
f0100b27:	a1 64 39 11 f0       	mov    0xf0113964,%eax
f0100b2c:	c1 e0 03             	shl    $0x3,%eax
f0100b2f:	e8 57 fd ff ff       	call   f010088b <boot_alloc>
f0100b34:	a3 6c 39 11 f0       	mov    %eax,0xf011396c
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f0100b39:	e8 24 fe ff ff       	call   f0100962 <page_init>
		cprintf("npages: %x \n", npages);
f0100b3e:	a1 64 39 11 f0       	mov    0xf0113964,%eax
f0100b43:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100b47:	c7 04 24 8c 22 10 f0 	movl   $0xf010228c,(%esp)
f0100b4e:	e8 a6 01 00 00       	call   f0100cf9 <cprintf>
  panic("mem_init: This function is not finished\n");
f0100b53:	c7 44 24 08 e8 21 10 	movl   $0xf01021e8,0x8(%esp)
f0100b5a:	f0 
f0100b5b:	c7 44 24 04 b7 00 00 	movl   $0xb7,0x4(%esp)
f0100b62:	00 
f0100b63:	c7 04 24 80 22 10 f0 	movl   $0xf0102280,(%esp)
f0100b6a:	e8 25 f5 ff ff       	call   f0100094 <_panic>

f0100b6f <page_alloc>:
//
// Hint: use page2kva and memset
// page2kva from pageInfo to virtual address
struct PageInfo *
page_alloc(int alloc_flags)
{
f0100b6f:	55                   	push   %ebp
f0100b70:	89 e5                	mov    %esp,%ebp
f0100b72:	83 ec 18             	sub    $0x18,%esp
	// Fill this function in
	if (alloc_flags & ALLOC_ZERO) // condition from the function comments
f0100b75:	f6 45 08 01          	testb  $0x1,0x8(%ebp)
f0100b79:	74 6f                	je     f0100bea <page_alloc+0x7b>
	{
		if(!page_free_list) // null if out of free memory
f0100b7b:	a1 3c 35 11 f0       	mov    0xf011353c,%eax
f0100b80:	85 c0                	test   %eax,%eax
f0100b82:	74 6d                	je     f0100bf1 <page_alloc+0x82>
			return NULL;
		struct PageInfo * tmp = page_free_list; // tmp to store the pageInfo that will be filled
		page_free_list = (*tmp).pp_link; // The next free page is change to the next one
f0100b84:	8b 10                	mov    (%eax),%edx
f0100b86:	89 15 3c 35 11 f0    	mov    %edx,0xf011353c
		(*tmp).pp_link = NULL; // indication that it is filled
f0100b8c:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
void	tlb_invalidate(pde_t *pgdir, void *va);

static inline physaddr_t
page2pa(struct PageInfo *pp)
{
	return (pp - pages) << PGSHIFT;
f0100b92:	2b 05 6c 39 11 f0    	sub    0xf011396c,%eax
f0100b98:	c1 f8 03             	sar    $0x3,%eax
f0100b9b:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100b9e:	89 c2                	mov    %eax,%edx
f0100ba0:	c1 ea 0c             	shr    $0xc,%edx
f0100ba3:	3b 15 64 39 11 f0    	cmp    0xf0113964,%edx
f0100ba9:	72 20                	jb     f0100bcb <page_alloc+0x5c>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100bab:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100baf:	c7 44 24 08 14 22 10 	movl   $0xf0102214,0x8(%esp)
f0100bb6:	f0 
f0100bb7:	c7 44 24 04 52 00 00 	movl   $0x52,0x4(%esp)
f0100bbe:	00 
f0100bbf:	c7 04 24 99 22 10 f0 	movl   $0xf0102299,(%esp)
f0100bc6:	e8 c9 f4 ff ff       	call   f0100094 <_panic>
		return memset(page2kva(tmp),'\0',PGSIZE); // fill the page with '\0'
f0100bcb:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0100bd2:	00 
f0100bd3:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0100bda:	00 
	return (void *)(pa + KERNBASE);
f0100bdb:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100be0:	89 04 24             	mov    %eax,(%esp)
f0100be3:	e8 0f 0c 00 00       	call   f01017f7 <memset>
f0100be8:	eb 0c                	jmp    f0100bf6 <page_alloc+0x87>
	}

	return NULL;
f0100bea:	b8 00 00 00 00       	mov    $0x0,%eax
f0100bef:	eb 05                	jmp    f0100bf6 <page_alloc+0x87>
{
	// Fill this function in
	if (alloc_flags & ALLOC_ZERO) // condition from the function comments
	{
		if(!page_free_list) // null if out of free memory
			return NULL;
f0100bf1:	b8 00 00 00 00       	mov    $0x0,%eax
		(*tmp).pp_link = NULL; // indication that it is filled
		return memset(page2kva(tmp),'\0',PGSIZE); // fill the page with '\0'
	}

	return NULL;
}
f0100bf6:	c9                   	leave  
f0100bf7:	c3                   	ret    

f0100bf8 <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct PageInfo *pp)
{
f0100bf8:	55                   	push   %ebp
f0100bf9:	89 e5                	mov    %esp,%ebp
f0100bfb:	83 ec 18             	sub    $0x18,%esp
f0100bfe:	8b 45 08             	mov    0x8(%ebp),%eax
	// Fill this function in
	// Hint: You may want to panic if pp->pp_ref is nonzero or
	// pp->pp_link is not NULL.
	if(pp->pp_ref != 0 || !pp->pp_link)
f0100c01:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0100c06:	75 05                	jne    f0100c0d <page_free+0x15>
f0100c08:	83 38 00             	cmpl   $0x0,(%eax)
f0100c0b:	75 1c                	jne    f0100c29 <page_free+0x31>
		panic("page_free: reference count is non zero or next free page is not null");
f0100c0d:	c7 44 24 08 38 22 10 	movl   $0xf0102238,0x8(%esp)
f0100c14:	f0 
f0100c15:	c7 44 24 04 63 01 00 	movl   $0x163,0x4(%esp)
f0100c1c:	00 
f0100c1d:	c7 04 24 80 22 10 f0 	movl   $0xf0102280,(%esp)
f0100c24:	e8 6b f4 ff ff       	call   f0100094 <_panic>
	struct PageInfo * tmp = page_free_list;
f0100c29:	8b 15 3c 35 11 f0    	mov    0xf011353c,%edx
	page_free_list = pp;
f0100c2f:	a3 3c 35 11 f0       	mov    %eax,0xf011353c
	(*pp).pp_link = tmp;
f0100c34:	89 10                	mov    %edx,(%eax)
}
f0100c36:	c9                   	leave  
f0100c37:	c3                   	ret    

f0100c38 <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct PageInfo* pp)
{
f0100c38:	55                   	push   %ebp
f0100c39:	89 e5                	mov    %esp,%ebp
f0100c3b:	83 ec 18             	sub    $0x18,%esp
f0100c3e:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f0100c41:	0f b7 48 04          	movzwl 0x4(%eax),%ecx
f0100c45:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0100c48:	66 89 50 04          	mov    %dx,0x4(%eax)
f0100c4c:	66 85 d2             	test   %dx,%dx
f0100c4f:	75 08                	jne    f0100c59 <page_decref+0x21>
		page_free(pp);
f0100c51:	89 04 24             	mov    %eax,(%esp)
f0100c54:	e8 9f ff ff ff       	call   f0100bf8 <page_free>
}
f0100c59:	c9                   	leave  
f0100c5a:	c3                   	ret    

f0100c5b <pgdir_walk>:
// table and page directory entries.
//

pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f0100c5b:	55                   	push   %ebp
f0100c5c:	89 e5                	mov    %esp,%ebp
	// 		return NULL;
	// 	}
	// 	(*tmp).pp_ref++;
	// }
	return NULL;
}
f0100c5e:	b8 00 00 00 00       	mov    $0x0,%eax
f0100c63:	5d                   	pop    %ebp
f0100c64:	c3                   	ret    

f0100c65 <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct PageInfo *pp, void *va, int perm)
{
f0100c65:	55                   	push   %ebp
f0100c66:	89 e5                	mov    %esp,%ebp
	// Fill this function in
	return 0;
}
f0100c68:	b8 00 00 00 00       	mov    $0x0,%eax
f0100c6d:	5d                   	pop    %ebp
f0100c6e:	c3                   	ret    

f0100c6f <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct PageInfo *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f0100c6f:	55                   	push   %ebp
f0100c70:	89 e5                	mov    %esp,%ebp
	// Fill this function in
	return NULL;
}
f0100c72:	b8 00 00 00 00       	mov    $0x0,%eax
f0100c77:	5d                   	pop    %ebp
f0100c78:	c3                   	ret    

f0100c79 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f0100c79:	55                   	push   %ebp
f0100c7a:	89 e5                	mov    %esp,%ebp
	// Fill this function in
}
f0100c7c:	5d                   	pop    %ebp
f0100c7d:	c3                   	ret    

f0100c7e <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f0100c7e:	55                   	push   %ebp
f0100c7f:	89 e5                	mov    %esp,%ebp
}

static inline void
invlpg(void *addr)
{
	asm volatile("invlpg (%0)" : : "r" (addr) : "memory");
f0100c81:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100c84:	0f 01 38             	invlpg (%eax)
	// Flush the entry only if we're modifying the current address space.
	// For now, there is only one address space, so always invalidate.
	invlpg(va);
}
f0100c87:	5d                   	pop    %ebp
f0100c88:	c3                   	ret    

f0100c89 <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0100c89:	55                   	push   %ebp
f0100c8a:	89 e5                	mov    %esp,%ebp
f0100c8c:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100c90:	ba 70 00 00 00       	mov    $0x70,%edx
f0100c95:	ee                   	out    %al,(%dx)

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100c96:	b2 71                	mov    $0x71,%dl
f0100c98:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0100c99:	0f b6 c0             	movzbl %al,%eax
}
f0100c9c:	5d                   	pop    %ebp
f0100c9d:	c3                   	ret    

f0100c9e <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0100c9e:	55                   	push   %ebp
f0100c9f:	89 e5                	mov    %esp,%ebp
f0100ca1:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100ca5:	ba 70 00 00 00       	mov    $0x70,%edx
f0100caa:	ee                   	out    %al,(%dx)
f0100cab:	b2 71                	mov    $0x71,%dl
f0100cad:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100cb0:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0100cb1:	5d                   	pop    %ebp
f0100cb2:	c3                   	ret    

f0100cb3 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0100cb3:	55                   	push   %ebp
f0100cb4:	89 e5                	mov    %esp,%ebp
f0100cb6:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0100cb9:	8b 45 08             	mov    0x8(%ebp),%eax
f0100cbc:	89 04 24             	mov    %eax,(%esp)
f0100cbf:	e8 3d f9 ff ff       	call   f0100601 <cputchar>
	*cnt++;
}
f0100cc4:	c9                   	leave  
f0100cc5:	c3                   	ret    

f0100cc6 <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0100cc6:	55                   	push   %ebp
f0100cc7:	89 e5                	mov    %esp,%ebp
f0100cc9:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0100ccc:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0100cd3:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100cd6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100cda:	8b 45 08             	mov    0x8(%ebp),%eax
f0100cdd:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100ce1:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0100ce4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100ce8:	c7 04 24 b3 0c 10 f0 	movl   $0xf0100cb3,(%esp)
f0100cef:	e8 4a 04 00 00       	call   f010113e <vprintfmt>
	return cnt;
}
f0100cf4:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0100cf7:	c9                   	leave  
f0100cf8:	c3                   	ret    

f0100cf9 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0100cf9:	55                   	push   %ebp
f0100cfa:	89 e5                	mov    %esp,%ebp
f0100cfc:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0100cff:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0100d02:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100d06:	8b 45 08             	mov    0x8(%ebp),%eax
f0100d09:	89 04 24             	mov    %eax,(%esp)
f0100d0c:	e8 b5 ff ff ff       	call   f0100cc6 <vcprintf>
	va_end(ap);

	return cnt;
}
f0100d11:	c9                   	leave  
f0100d12:	c3                   	ret    

f0100d13 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0100d13:	55                   	push   %ebp
f0100d14:	89 e5                	mov    %esp,%ebp
f0100d16:	57                   	push   %edi
f0100d17:	56                   	push   %esi
f0100d18:	53                   	push   %ebx
f0100d19:	83 ec 10             	sub    $0x10,%esp
f0100d1c:	89 c6                	mov    %eax,%esi
f0100d1e:	89 55 e8             	mov    %edx,-0x18(%ebp)
f0100d21:	89 4d e4             	mov    %ecx,-0x1c(%ebp)
f0100d24:	8b 7d 08             	mov    0x8(%ebp),%edi
	int l = *region_left, r = *region_right, any_matches = 0;
f0100d27:	8b 1a                	mov    (%edx),%ebx
f0100d29:	8b 01                	mov    (%ecx),%eax
f0100d2b:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0100d2e:	c7 45 ec 00 00 00 00 	movl   $0x0,-0x14(%ebp)

	while (l <= r) {
f0100d35:	eb 77                	jmp    f0100dae <stab_binsearch+0x9b>
		int true_m = (l + r) / 2, m = true_m;
f0100d37:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0100d3a:	01 d8                	add    %ebx,%eax
f0100d3c:	b9 02 00 00 00       	mov    $0x2,%ecx
f0100d41:	99                   	cltd   
f0100d42:	f7 f9                	idiv   %ecx
f0100d44:	89 c1                	mov    %eax,%ecx

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0100d46:	eb 01                	jmp    f0100d49 <stab_binsearch+0x36>
			m--;
f0100d48:	49                   	dec    %ecx

	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0100d49:	39 d9                	cmp    %ebx,%ecx
f0100d4b:	7c 1d                	jl     f0100d6a <stab_binsearch+0x57>
f0100d4d:	6b d1 0c             	imul   $0xc,%ecx,%edx
f0100d50:	0f b6 54 16 04       	movzbl 0x4(%esi,%edx,1),%edx
f0100d55:	39 fa                	cmp    %edi,%edx
f0100d57:	75 ef                	jne    f0100d48 <stab_binsearch+0x35>
f0100d59:	89 4d ec             	mov    %ecx,-0x14(%ebp)
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0100d5c:	6b d1 0c             	imul   $0xc,%ecx,%edx
f0100d5f:	8b 54 16 08          	mov    0x8(%esi,%edx,1),%edx
f0100d63:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0100d66:	73 18                	jae    f0100d80 <stab_binsearch+0x6d>
f0100d68:	eb 05                	jmp    f0100d6f <stab_binsearch+0x5c>

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0100d6a:	8d 58 01             	lea    0x1(%eax),%ebx
			continue;
f0100d6d:	eb 3f                	jmp    f0100dae <stab_binsearch+0x9b>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0100d6f:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f0100d72:	89 0b                	mov    %ecx,(%ebx)
			l = true_m + 1;
f0100d74:	8d 58 01             	lea    0x1(%eax),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100d77:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f0100d7e:	eb 2e                	jmp    f0100dae <stab_binsearch+0x9b>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0100d80:	39 55 0c             	cmp    %edx,0xc(%ebp)
f0100d83:	73 15                	jae    f0100d9a <stab_binsearch+0x87>
			*region_right = m - 1;
f0100d85:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0100d88:	48                   	dec    %eax
f0100d89:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0100d8c:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0100d8f:	89 01                	mov    %eax,(%ecx)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100d91:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f0100d98:	eb 14                	jmp    f0100dae <stab_binsearch+0x9b>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f0100d9a:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0100d9d:	8b 5d ec             	mov    -0x14(%ebp),%ebx
f0100da0:	89 18                	mov    %ebx,(%eax)
			l = m;
			addr++;
f0100da2:	ff 45 0c             	incl   0xc(%ebp)
f0100da5:	89 cb                	mov    %ecx,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100da7:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;

	while (l <= r) {
f0100dae:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0100db1:	7e 84                	jle    f0100d37 <stab_binsearch+0x24>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0100db3:	83 7d ec 00          	cmpl   $0x0,-0x14(%ebp)
f0100db7:	75 0d                	jne    f0100dc6 <stab_binsearch+0xb3>
		*region_right = *region_left - 1;
f0100db9:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0100dbc:	8b 00                	mov    (%eax),%eax
f0100dbe:	48                   	dec    %eax
f0100dbf:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0100dc2:	89 07                	mov    %eax,(%edi)
f0100dc4:	eb 22                	jmp    f0100de8 <stab_binsearch+0xd5>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100dc6:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100dc9:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0100dcb:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f0100dce:	8b 0b                	mov    (%ebx),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100dd0:	eb 01                	jmp    f0100dd3 <stab_binsearch+0xc0>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
f0100dd2:	48                   	dec    %eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100dd3:	39 c1                	cmp    %eax,%ecx
f0100dd5:	7d 0c                	jge    f0100de3 <stab_binsearch+0xd0>
f0100dd7:	6b d0 0c             	imul   $0xc,%eax,%edx
		     l > *region_left && stabs[l].n_type != type;
f0100dda:	0f b6 54 16 04       	movzbl 0x4(%esi,%edx,1),%edx
f0100ddf:	39 fa                	cmp    %edi,%edx
f0100de1:	75 ef                	jne    f0100dd2 <stab_binsearch+0xbf>
		     l--)
			/* do nothing */;
		*region_left = l;
f0100de3:	8b 7d e8             	mov    -0x18(%ebp),%edi
f0100de6:	89 07                	mov    %eax,(%edi)
	}
}
f0100de8:	83 c4 10             	add    $0x10,%esp
f0100deb:	5b                   	pop    %ebx
f0100dec:	5e                   	pop    %esi
f0100ded:	5f                   	pop    %edi
f0100dee:	5d                   	pop    %ebp
f0100def:	c3                   	ret    

f0100df0 <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0100df0:	55                   	push   %ebp
f0100df1:	89 e5                	mov    %esp,%ebp
f0100df3:	57                   	push   %edi
f0100df4:	56                   	push   %esi
f0100df5:	53                   	push   %ebx
f0100df6:	83 ec 2c             	sub    $0x2c,%esp
f0100df9:	8b 75 08             	mov    0x8(%ebp),%esi
f0100dfc:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0100dff:	c7 03 a7 22 10 f0    	movl   $0xf01022a7,(%ebx)
	info->eip_line = 0;
f0100e05:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
	info->eip_fn_name = "<unknown>";
f0100e0c:	c7 43 08 a7 22 10 f0 	movl   $0xf01022a7,0x8(%ebx)
	info->eip_fn_namelen = 9;
f0100e13:	c7 43 0c 09 00 00 00 	movl   $0x9,0xc(%ebx)
	info->eip_fn_addr = addr;
f0100e1a:	89 73 10             	mov    %esi,0x10(%ebx)
	info->eip_fn_narg = 0;
f0100e1d:	c7 43 14 00 00 00 00 	movl   $0x0,0x14(%ebx)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0100e24:	81 fe ff ff 7f ef    	cmp    $0xef7fffff,%esi
f0100e2a:	76 12                	jbe    f0100e3e <debuginfo_eip+0x4e>
		// Can't search for user-level addresses yet!
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0100e2c:	b8 02 84 10 f0       	mov    $0xf0108402,%eax
f0100e31:	3d 3d 68 10 f0       	cmp    $0xf010683d,%eax
f0100e36:	0f 86 6b 01 00 00    	jbe    f0100fa7 <debuginfo_eip+0x1b7>
f0100e3c:	eb 1c                	jmp    f0100e5a <debuginfo_eip+0x6a>
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
	} else {
		// Can't search for user-level addresses yet!
  	        panic("User address");
f0100e3e:	c7 44 24 08 b1 22 10 	movl   $0xf01022b1,0x8(%esp)
f0100e45:	f0 
f0100e46:	c7 44 24 04 7f 00 00 	movl   $0x7f,0x4(%esp)
f0100e4d:	00 
f0100e4e:	c7 04 24 be 22 10 f0 	movl   $0xf01022be,(%esp)
f0100e55:	e8 3a f2 ff ff       	call   f0100094 <_panic>
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0100e5a:	80 3d 01 84 10 f0 00 	cmpb   $0x0,0xf0108401
f0100e61:	0f 85 47 01 00 00    	jne    f0100fae <debuginfo_eip+0x1be>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.

	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0100e67:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0100e6e:	b8 3c 68 10 f0       	mov    $0xf010683c,%eax
f0100e73:	2d e0 24 10 f0       	sub    $0xf01024e0,%eax
f0100e78:	c1 f8 02             	sar    $0x2,%eax
f0100e7b:	69 c0 ab aa aa aa    	imul   $0xaaaaaaab,%eax,%eax
f0100e81:	83 e8 01             	sub    $0x1,%eax
f0100e84:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0100e87:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100e8b:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f0100e92:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0100e95:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0100e98:	b8 e0 24 10 f0       	mov    $0xf01024e0,%eax
f0100e9d:	e8 71 fe ff ff       	call   f0100d13 <stab_binsearch>
	if (lfile == 0)
f0100ea2:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100ea5:	85 c0                	test   %eax,%eax
f0100ea7:	0f 84 08 01 00 00    	je     f0100fb5 <debuginfo_eip+0x1c5>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0100ead:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0100eb0:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100eb3:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0100eb6:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100eba:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0100ec1:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0100ec4:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100ec7:	b8 e0 24 10 f0       	mov    $0xf01024e0,%eax
f0100ecc:	e8 42 fe ff ff       	call   f0100d13 <stab_binsearch>

	if (lfun <= rfun) {
f0100ed1:	8b 7d dc             	mov    -0x24(%ebp),%edi
f0100ed4:	3b 7d d8             	cmp    -0x28(%ebp),%edi
f0100ed7:	7f 2e                	jg     f0100f07 <debuginfo_eip+0x117>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0100ed9:	6b c7 0c             	imul   $0xc,%edi,%eax
f0100edc:	8d 90 e0 24 10 f0    	lea    -0xfefdb20(%eax),%edx
f0100ee2:	8b 80 e0 24 10 f0    	mov    -0xfefdb20(%eax),%eax
f0100ee8:	b9 02 84 10 f0       	mov    $0xf0108402,%ecx
f0100eed:	81 e9 3d 68 10 f0    	sub    $0xf010683d,%ecx
f0100ef3:	39 c8                	cmp    %ecx,%eax
f0100ef5:	73 08                	jae    f0100eff <debuginfo_eip+0x10f>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0100ef7:	05 3d 68 10 f0       	add    $0xf010683d,%eax
f0100efc:	89 43 08             	mov    %eax,0x8(%ebx)
		info->eip_fn_addr = stabs[lfun].n_value;
f0100eff:	8b 42 08             	mov    0x8(%edx),%eax
f0100f02:	89 43 10             	mov    %eax,0x10(%ebx)
f0100f05:	eb 06                	jmp    f0100f0d <debuginfo_eip+0x11d>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0100f07:	89 73 10             	mov    %esi,0x10(%ebx)
		lline = lfile;
f0100f0a:	8b 7d e4             	mov    -0x1c(%ebp),%edi
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0100f0d:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0100f14:	00 
f0100f15:	8b 43 08             	mov    0x8(%ebx),%eax
f0100f18:	89 04 24             	mov    %eax,(%esp)
f0100f1b:	e8 bb 08 00 00       	call   f01017db <strfind>
f0100f20:	2b 43 08             	sub    0x8(%ebx),%eax
f0100f23:	89 43 0c             	mov    %eax,0xc(%ebx)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0100f26:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0100f29:	6b c7 0c             	imul   $0xc,%edi,%eax
f0100f2c:	05 e0 24 10 f0       	add    $0xf01024e0,%eax
f0100f31:	eb 06                	jmp    f0100f39 <debuginfo_eip+0x149>
	       && stabs[lline].n_type != N_SOL
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0100f33:	83 ef 01             	sub    $0x1,%edi
f0100f36:	83 e8 0c             	sub    $0xc,%eax
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0100f39:	39 cf                	cmp    %ecx,%edi
f0100f3b:	7c 33                	jl     f0100f70 <debuginfo_eip+0x180>
	       && stabs[lline].n_type != N_SOL
f0100f3d:	0f b6 50 04          	movzbl 0x4(%eax),%edx
f0100f41:	80 fa 84             	cmp    $0x84,%dl
f0100f44:	74 0b                	je     f0100f51 <debuginfo_eip+0x161>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0100f46:	80 fa 64             	cmp    $0x64,%dl
f0100f49:	75 e8                	jne    f0100f33 <debuginfo_eip+0x143>
f0100f4b:	83 78 08 00          	cmpl   $0x0,0x8(%eax)
f0100f4f:	74 e2                	je     f0100f33 <debuginfo_eip+0x143>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0100f51:	6b ff 0c             	imul   $0xc,%edi,%edi
f0100f54:	8b 87 e0 24 10 f0    	mov    -0xfefdb20(%edi),%eax
f0100f5a:	ba 02 84 10 f0       	mov    $0xf0108402,%edx
f0100f5f:	81 ea 3d 68 10 f0    	sub    $0xf010683d,%edx
f0100f65:	39 d0                	cmp    %edx,%eax
f0100f67:	73 07                	jae    f0100f70 <debuginfo_eip+0x180>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0100f69:	05 3d 68 10 f0       	add    $0xf010683d,%eax
f0100f6e:	89 03                	mov    %eax,(%ebx)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0100f70:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0100f73:	8b 75 d8             	mov    -0x28(%ebp),%esi
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;

	return 0;
f0100f76:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0100f7b:	39 f1                	cmp    %esi,%ecx
f0100f7d:	7d 42                	jge    f0100fc1 <debuginfo_eip+0x1d1>
		for (lline = lfun + 1;
f0100f7f:	8d 51 01             	lea    0x1(%ecx),%edx
f0100f82:	6b c1 0c             	imul   $0xc,%ecx,%eax
f0100f85:	05 e0 24 10 f0       	add    $0xf01024e0,%eax
f0100f8a:	eb 07                	jmp    f0100f93 <debuginfo_eip+0x1a3>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
f0100f8c:	83 43 14 01          	addl   $0x1,0x14(%ebx)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0100f90:	83 c2 01             	add    $0x1,%edx


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0100f93:	39 f2                	cmp    %esi,%edx
f0100f95:	74 25                	je     f0100fbc <debuginfo_eip+0x1cc>
f0100f97:	83 c0 0c             	add    $0xc,%eax
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0100f9a:	80 78 04 a0          	cmpb   $0xa0,0x4(%eax)
f0100f9e:	74 ec                	je     f0100f8c <debuginfo_eip+0x19c>
		     lline++)
			info->eip_fn_narg++;

	return 0;
f0100fa0:	b8 00 00 00 00       	mov    $0x0,%eax
f0100fa5:	eb 1a                	jmp    f0100fc1 <debuginfo_eip+0x1d1>
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0100fa7:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100fac:	eb 13                	jmp    f0100fc1 <debuginfo_eip+0x1d1>
f0100fae:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100fb3:	eb 0c                	jmp    f0100fc1 <debuginfo_eip+0x1d1>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0100fb5:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100fba:	eb 05                	jmp    f0100fc1 <debuginfo_eip+0x1d1>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;

	return 0;
f0100fbc:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0100fc1:	83 c4 2c             	add    $0x2c,%esp
f0100fc4:	5b                   	pop    %ebx
f0100fc5:	5e                   	pop    %esi
f0100fc6:	5f                   	pop    %edi
f0100fc7:	5d                   	pop    %ebp
f0100fc8:	c3                   	ret    
f0100fc9:	66 90                	xchg   %ax,%ax
f0100fcb:	66 90                	xchg   %ax,%ax
f0100fcd:	66 90                	xchg   %ax,%ax
f0100fcf:	90                   	nop

f0100fd0 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0100fd0:	55                   	push   %ebp
f0100fd1:	89 e5                	mov    %esp,%ebp
f0100fd3:	57                   	push   %edi
f0100fd4:	56                   	push   %esi
f0100fd5:	53                   	push   %ebx
f0100fd6:	83 ec 3c             	sub    $0x3c,%esp
f0100fd9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0100fdc:	89 d7                	mov    %edx,%edi
f0100fde:	8b 45 08             	mov    0x8(%ebp),%eax
f0100fe1:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0100fe4:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100fe7:	89 c3                	mov    %eax,%ebx
f0100fe9:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0100fec:	8b 45 10             	mov    0x10(%ebp),%eax
f0100fef:	8b 75 14             	mov    0x14(%ebp),%esi
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0100ff2:	b9 00 00 00 00       	mov    $0x0,%ecx
f0100ff7:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0100ffa:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0100ffd:	39 d9                	cmp    %ebx,%ecx
f0100fff:	72 05                	jb     f0101006 <printnum+0x36>
f0101001:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f0101004:	77 69                	ja     f010106f <printnum+0x9f>
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0101006:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0101009:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f010100d:	83 ee 01             	sub    $0x1,%esi
f0101010:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0101014:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101018:	8b 44 24 08          	mov    0x8(%esp),%eax
f010101c:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0101020:	89 c3                	mov    %eax,%ebx
f0101022:	89 d6                	mov    %edx,%esi
f0101024:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0101027:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f010102a:	89 54 24 08          	mov    %edx,0x8(%esp)
f010102e:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0101032:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0101035:	89 04 24             	mov    %eax,(%esp)
f0101038:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010103b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010103f:	e8 bc 09 00 00       	call   f0101a00 <__udivdi3>
f0101044:	89 d9                	mov    %ebx,%ecx
f0101046:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f010104a:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010104e:	89 04 24             	mov    %eax,(%esp)
f0101051:	89 54 24 04          	mov    %edx,0x4(%esp)
f0101055:	89 fa                	mov    %edi,%edx
f0101057:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010105a:	e8 71 ff ff ff       	call   f0100fd0 <printnum>
f010105f:	eb 1b                	jmp    f010107c <printnum+0xac>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f0101061:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101065:	8b 45 18             	mov    0x18(%ebp),%eax
f0101068:	89 04 24             	mov    %eax,(%esp)
f010106b:	ff d3                	call   *%ebx
f010106d:	eb 03                	jmp    f0101072 <printnum+0xa2>
f010106f:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0101072:	83 ee 01             	sub    $0x1,%esi
f0101075:	85 f6                	test   %esi,%esi
f0101077:	7f e8                	jg     f0101061 <printnum+0x91>
f0101079:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f010107c:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101080:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0101084:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0101087:	8b 55 dc             	mov    -0x24(%ebp),%edx
f010108a:	89 44 24 08          	mov    %eax,0x8(%esp)
f010108e:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101092:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0101095:	89 04 24             	mov    %eax,(%esp)
f0101098:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010109b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010109f:	e8 8c 0a 00 00       	call   f0101b30 <__umoddi3>
f01010a4:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01010a8:	0f be 80 cc 22 10 f0 	movsbl -0xfefdd34(%eax),%eax
f01010af:	89 04 24             	mov    %eax,(%esp)
f01010b2:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01010b5:	ff d0                	call   *%eax
}
f01010b7:	83 c4 3c             	add    $0x3c,%esp
f01010ba:	5b                   	pop    %ebx
f01010bb:	5e                   	pop    %esi
f01010bc:	5f                   	pop    %edi
f01010bd:	5d                   	pop    %ebp
f01010be:	c3                   	ret    

f01010bf <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f01010bf:	55                   	push   %ebp
f01010c0:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f01010c2:	83 fa 01             	cmp    $0x1,%edx
f01010c5:	7e 0e                	jle    f01010d5 <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f01010c7:	8b 10                	mov    (%eax),%edx
f01010c9:	8d 4a 08             	lea    0x8(%edx),%ecx
f01010cc:	89 08                	mov    %ecx,(%eax)
f01010ce:	8b 02                	mov    (%edx),%eax
f01010d0:	8b 52 04             	mov    0x4(%edx),%edx
f01010d3:	eb 22                	jmp    f01010f7 <getuint+0x38>
	else if (lflag)
f01010d5:	85 d2                	test   %edx,%edx
f01010d7:	74 10                	je     f01010e9 <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f01010d9:	8b 10                	mov    (%eax),%edx
f01010db:	8d 4a 04             	lea    0x4(%edx),%ecx
f01010de:	89 08                	mov    %ecx,(%eax)
f01010e0:	8b 02                	mov    (%edx),%eax
f01010e2:	ba 00 00 00 00       	mov    $0x0,%edx
f01010e7:	eb 0e                	jmp    f01010f7 <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f01010e9:	8b 10                	mov    (%eax),%edx
f01010eb:	8d 4a 04             	lea    0x4(%edx),%ecx
f01010ee:	89 08                	mov    %ecx,(%eax)
f01010f0:	8b 02                	mov    (%edx),%eax
f01010f2:	ba 00 00 00 00       	mov    $0x0,%edx
}
f01010f7:	5d                   	pop    %ebp
f01010f8:	c3                   	ret    

f01010f9 <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f01010f9:	55                   	push   %ebp
f01010fa:	89 e5                	mov    %esp,%ebp
f01010fc:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f01010ff:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0101103:	8b 10                	mov    (%eax),%edx
f0101105:	3b 50 04             	cmp    0x4(%eax),%edx
f0101108:	73 0a                	jae    f0101114 <sprintputch+0x1b>
		*b->buf++ = ch;
f010110a:	8d 4a 01             	lea    0x1(%edx),%ecx
f010110d:	89 08                	mov    %ecx,(%eax)
f010110f:	8b 45 08             	mov    0x8(%ebp),%eax
f0101112:	88 02                	mov    %al,(%edx)
}
f0101114:	5d                   	pop    %ebp
f0101115:	c3                   	ret    

f0101116 <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f0101116:	55                   	push   %ebp
f0101117:	89 e5                	mov    %esp,%ebp
f0101119:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f010111c:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f010111f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101123:	8b 45 10             	mov    0x10(%ebp),%eax
f0101126:	89 44 24 08          	mov    %eax,0x8(%esp)
f010112a:	8b 45 0c             	mov    0xc(%ebp),%eax
f010112d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101131:	8b 45 08             	mov    0x8(%ebp),%eax
f0101134:	89 04 24             	mov    %eax,(%esp)
f0101137:	e8 02 00 00 00       	call   f010113e <vprintfmt>
	va_end(ap);
}
f010113c:	c9                   	leave  
f010113d:	c3                   	ret    

f010113e <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f010113e:	55                   	push   %ebp
f010113f:	89 e5                	mov    %esp,%ebp
f0101141:	57                   	push   %edi
f0101142:	56                   	push   %esi
f0101143:	53                   	push   %ebx
f0101144:	83 ec 3c             	sub    $0x3c,%esp
f0101147:	8b 7d 0c             	mov    0xc(%ebp),%edi
f010114a:	8b 5d 10             	mov    0x10(%ebp),%ebx
f010114d:	eb 14                	jmp    f0101163 <vprintfmt+0x25>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f010114f:	85 c0                	test   %eax,%eax
f0101151:	0f 84 b3 03 00 00    	je     f010150a <vprintfmt+0x3cc>
				return;
			putch(ch, putdat);
f0101157:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010115b:	89 04 24             	mov    %eax,(%esp)
f010115e:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0101161:	89 f3                	mov    %esi,%ebx
f0101163:	8d 73 01             	lea    0x1(%ebx),%esi
f0101166:	0f b6 03             	movzbl (%ebx),%eax
f0101169:	83 f8 25             	cmp    $0x25,%eax
f010116c:	75 e1                	jne    f010114f <vprintfmt+0x11>
f010116e:	c6 45 d8 20          	movb   $0x20,-0x28(%ebp)
f0101172:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0101179:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f0101180:	c7 45 dc ff ff ff ff 	movl   $0xffffffff,-0x24(%ebp)
f0101187:	ba 00 00 00 00       	mov    $0x0,%edx
f010118c:	eb 1d                	jmp    f01011ab <vprintfmt+0x6d>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010118e:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f0101190:	c6 45 d8 2d          	movb   $0x2d,-0x28(%ebp)
f0101194:	eb 15                	jmp    f01011ab <vprintfmt+0x6d>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0101196:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;

		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0101198:	c6 45 d8 30          	movb   $0x30,-0x28(%ebp)
f010119c:	eb 0d                	jmp    f01011ab <vprintfmt+0x6d>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f010119e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01011a1:	89 45 dc             	mov    %eax,-0x24(%ebp)
f01011a4:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01011ab:	8d 5e 01             	lea    0x1(%esi),%ebx
f01011ae:	0f b6 0e             	movzbl (%esi),%ecx
f01011b1:	0f b6 c1             	movzbl %cl,%eax
f01011b4:	83 e9 23             	sub    $0x23,%ecx
f01011b7:	80 f9 55             	cmp    $0x55,%cl
f01011ba:	0f 87 2a 03 00 00    	ja     f01014ea <vprintfmt+0x3ac>
f01011c0:	0f b6 c9             	movzbl %cl,%ecx
f01011c3:	ff 24 8d 5c 23 10 f0 	jmp    *-0xfefdca4(,%ecx,4)
f01011ca:	89 de                	mov    %ebx,%esi
f01011cc:	b9 00 00 00 00       	mov    $0x0,%ecx
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f01011d1:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f01011d4:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f01011d8:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f01011db:	8d 58 d0             	lea    -0x30(%eax),%ebx
f01011de:	83 fb 09             	cmp    $0x9,%ebx
f01011e1:	77 36                	ja     f0101219 <vprintfmt+0xdb>
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f01011e3:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
				ch = *fmt;
				if (ch < '0' || ch > '9')
					break;
			}
f01011e6:	eb e9                	jmp    f01011d1 <vprintfmt+0x93>
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f01011e8:	8b 45 14             	mov    0x14(%ebp),%eax
f01011eb:	8d 48 04             	lea    0x4(%eax),%ecx
f01011ee:	89 4d 14             	mov    %ecx,0x14(%ebp)
f01011f1:	8b 00                	mov    (%eax),%eax
f01011f3:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01011f6:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f01011f8:	eb 22                	jmp    f010121c <vprintfmt+0xde>
f01011fa:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f01011fd:	85 c9                	test   %ecx,%ecx
f01011ff:	b8 00 00 00 00       	mov    $0x0,%eax
f0101204:	0f 49 c1             	cmovns %ecx,%eax
f0101207:	89 45 dc             	mov    %eax,-0x24(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010120a:	89 de                	mov    %ebx,%esi
f010120c:	eb 9d                	jmp    f01011ab <vprintfmt+0x6d>
f010120e:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0101210:	c7 45 e0 01 00 00 00 	movl   $0x1,-0x20(%ebp)
			goto reswitch;
f0101217:	eb 92                	jmp    f01011ab <vprintfmt+0x6d>
f0101219:	89 4d d4             	mov    %ecx,-0x2c(%ebp)

		process_precision:
			if (width < 0)
f010121c:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f0101220:	79 89                	jns    f01011ab <vprintfmt+0x6d>
f0101222:	e9 77 ff ff ff       	jmp    f010119e <vprintfmt+0x60>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0101227:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010122a:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f010122c:	e9 7a ff ff ff       	jmp    f01011ab <vprintfmt+0x6d>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f0101231:	8b 45 14             	mov    0x14(%ebp),%eax
f0101234:	8d 50 04             	lea    0x4(%eax),%edx
f0101237:	89 55 14             	mov    %edx,0x14(%ebp)
f010123a:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010123e:	8b 00                	mov    (%eax),%eax
f0101240:	89 04 24             	mov    %eax,(%esp)
f0101243:	ff 55 08             	call   *0x8(%ebp)
			break;
f0101246:	e9 18 ff ff ff       	jmp    f0101163 <vprintfmt+0x25>

		// error message
		case 'e':
			err = va_arg(ap, int);
f010124b:	8b 45 14             	mov    0x14(%ebp),%eax
f010124e:	8d 50 04             	lea    0x4(%eax),%edx
f0101251:	89 55 14             	mov    %edx,0x14(%ebp)
f0101254:	8b 00                	mov    (%eax),%eax
f0101256:	99                   	cltd   
f0101257:	31 d0                	xor    %edx,%eax
f0101259:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f010125b:	83 f8 06             	cmp    $0x6,%eax
f010125e:	7f 0b                	jg     f010126b <vprintfmt+0x12d>
f0101260:	8b 14 85 b4 24 10 f0 	mov    -0xfefdb4c(,%eax,4),%edx
f0101267:	85 d2                	test   %edx,%edx
f0101269:	75 20                	jne    f010128b <vprintfmt+0x14d>
				printfmt(putch, putdat, "error %d", err);
f010126b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010126f:	c7 44 24 08 e4 22 10 	movl   $0xf01022e4,0x8(%esp)
f0101276:	f0 
f0101277:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010127b:	8b 45 08             	mov    0x8(%ebp),%eax
f010127e:	89 04 24             	mov    %eax,(%esp)
f0101281:	e8 90 fe ff ff       	call   f0101116 <printfmt>
f0101286:	e9 d8 fe ff ff       	jmp    f0101163 <vprintfmt+0x25>
			else
				printfmt(putch, putdat, "%s", p);
f010128b:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010128f:	c7 44 24 08 ed 22 10 	movl   $0xf01022ed,0x8(%esp)
f0101296:	f0 
f0101297:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010129b:	8b 45 08             	mov    0x8(%ebp),%eax
f010129e:	89 04 24             	mov    %eax,(%esp)
f01012a1:	e8 70 fe ff ff       	call   f0101116 <printfmt>
f01012a6:	e9 b8 fe ff ff       	jmp    f0101163 <vprintfmt+0x25>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01012ab:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01012ae:	8b 45 dc             	mov    -0x24(%ebp),%eax
f01012b1:	89 45 d0             	mov    %eax,-0x30(%ebp)
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f01012b4:	8b 45 14             	mov    0x14(%ebp),%eax
f01012b7:	8d 50 04             	lea    0x4(%eax),%edx
f01012ba:	89 55 14             	mov    %edx,0x14(%ebp)
f01012bd:	8b 30                	mov    (%eax),%esi
				p = "(null)";
f01012bf:	85 f6                	test   %esi,%esi
f01012c1:	b8 dd 22 10 f0       	mov    $0xf01022dd,%eax
f01012c6:	0f 44 f0             	cmove  %eax,%esi
			if (width > 0 && padc != '-')
f01012c9:	80 7d d8 2d          	cmpb   $0x2d,-0x28(%ebp)
f01012cd:	0f 84 97 00 00 00    	je     f010136a <vprintfmt+0x22c>
f01012d3:	83 7d d0 00          	cmpl   $0x0,-0x30(%ebp)
f01012d7:	0f 8e 9b 00 00 00    	jle    f0101378 <vprintfmt+0x23a>
				for (width -= strnlen(p, precision); width > 0; width--)
f01012dd:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01012e1:	89 34 24             	mov    %esi,(%esp)
f01012e4:	e8 9f 03 00 00       	call   f0101688 <strnlen>
f01012e9:	8b 55 d0             	mov    -0x30(%ebp),%edx
f01012ec:	29 c2                	sub    %eax,%edx
f01012ee:	89 55 d0             	mov    %edx,-0x30(%ebp)
					putch(padc, putdat);
f01012f1:	0f be 45 d8          	movsbl -0x28(%ebp),%eax
f01012f5:	89 45 dc             	mov    %eax,-0x24(%ebp)
f01012f8:	89 75 d8             	mov    %esi,-0x28(%ebp)
f01012fb:	8b 75 08             	mov    0x8(%ebp),%esi
f01012fe:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0101301:	89 d3                	mov    %edx,%ebx
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0101303:	eb 0f                	jmp    f0101314 <vprintfmt+0x1d6>
					putch(padc, putdat);
f0101305:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101309:	8b 45 dc             	mov    -0x24(%ebp),%eax
f010130c:	89 04 24             	mov    %eax,(%esp)
f010130f:	ff d6                	call   *%esi
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0101311:	83 eb 01             	sub    $0x1,%ebx
f0101314:	85 db                	test   %ebx,%ebx
f0101316:	7f ed                	jg     f0101305 <vprintfmt+0x1c7>
f0101318:	8b 75 d8             	mov    -0x28(%ebp),%esi
f010131b:	8b 55 d0             	mov    -0x30(%ebp),%edx
f010131e:	85 d2                	test   %edx,%edx
f0101320:	b8 00 00 00 00       	mov    $0x0,%eax
f0101325:	0f 49 c2             	cmovns %edx,%eax
f0101328:	29 c2                	sub    %eax,%edx
f010132a:	89 7d 0c             	mov    %edi,0xc(%ebp)
f010132d:	89 d7                	mov    %edx,%edi
f010132f:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0101332:	eb 50                	jmp    f0101384 <vprintfmt+0x246>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f0101334:	83 7d e0 00          	cmpl   $0x0,-0x20(%ebp)
f0101338:	74 1e                	je     f0101358 <vprintfmt+0x21a>
f010133a:	0f be d2             	movsbl %dl,%edx
f010133d:	83 ea 20             	sub    $0x20,%edx
f0101340:	83 fa 5e             	cmp    $0x5e,%edx
f0101343:	76 13                	jbe    f0101358 <vprintfmt+0x21a>
					putch('?', putdat);
f0101345:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101348:	89 44 24 04          	mov    %eax,0x4(%esp)
f010134c:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f0101353:	ff 55 08             	call   *0x8(%ebp)
f0101356:	eb 0d                	jmp    f0101365 <vprintfmt+0x227>
				else
					putch(ch, putdat);
f0101358:	8b 55 0c             	mov    0xc(%ebp),%edx
f010135b:	89 54 24 04          	mov    %edx,0x4(%esp)
f010135f:	89 04 24             	mov    %eax,(%esp)
f0101362:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0101365:	83 ef 01             	sub    $0x1,%edi
f0101368:	eb 1a                	jmp    f0101384 <vprintfmt+0x246>
f010136a:	89 7d 0c             	mov    %edi,0xc(%ebp)
f010136d:	8b 7d dc             	mov    -0x24(%ebp),%edi
f0101370:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0101373:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0101376:	eb 0c                	jmp    f0101384 <vprintfmt+0x246>
f0101378:	89 7d 0c             	mov    %edi,0xc(%ebp)
f010137b:	8b 7d dc             	mov    -0x24(%ebp),%edi
f010137e:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0101381:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0101384:	83 c6 01             	add    $0x1,%esi
f0101387:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f010138b:	0f be c2             	movsbl %dl,%eax
f010138e:	85 c0                	test   %eax,%eax
f0101390:	74 27                	je     f01013b9 <vprintfmt+0x27b>
f0101392:	85 db                	test   %ebx,%ebx
f0101394:	78 9e                	js     f0101334 <vprintfmt+0x1f6>
f0101396:	83 eb 01             	sub    $0x1,%ebx
f0101399:	79 99                	jns    f0101334 <vprintfmt+0x1f6>
f010139b:	89 f8                	mov    %edi,%eax
f010139d:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01013a0:	8b 75 08             	mov    0x8(%ebp),%esi
f01013a3:	89 c3                	mov    %eax,%ebx
f01013a5:	eb 1a                	jmp    f01013c1 <vprintfmt+0x283>
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f01013a7:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01013ab:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f01013b2:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01013b4:	83 eb 01             	sub    $0x1,%ebx
f01013b7:	eb 08                	jmp    f01013c1 <vprintfmt+0x283>
f01013b9:	89 fb                	mov    %edi,%ebx
f01013bb:	8b 75 08             	mov    0x8(%ebp),%esi
f01013be:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01013c1:	85 db                	test   %ebx,%ebx
f01013c3:	7f e2                	jg     f01013a7 <vprintfmt+0x269>
f01013c5:	89 75 08             	mov    %esi,0x8(%ebp)
f01013c8:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01013cb:	e9 93 fd ff ff       	jmp    f0101163 <vprintfmt+0x25>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f01013d0:	83 fa 01             	cmp    $0x1,%edx
f01013d3:	7e 16                	jle    f01013eb <vprintfmt+0x2ad>
		return va_arg(*ap, long long);
f01013d5:	8b 45 14             	mov    0x14(%ebp),%eax
f01013d8:	8d 50 08             	lea    0x8(%eax),%edx
f01013db:	89 55 14             	mov    %edx,0x14(%ebp)
f01013de:	8b 50 04             	mov    0x4(%eax),%edx
f01013e1:	8b 00                	mov    (%eax),%eax
f01013e3:	89 45 e0             	mov    %eax,-0x20(%ebp)
f01013e6:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f01013e9:	eb 32                	jmp    f010141d <vprintfmt+0x2df>
	else if (lflag)
f01013eb:	85 d2                	test   %edx,%edx
f01013ed:	74 18                	je     f0101407 <vprintfmt+0x2c9>
		return va_arg(*ap, long);
f01013ef:	8b 45 14             	mov    0x14(%ebp),%eax
f01013f2:	8d 50 04             	lea    0x4(%eax),%edx
f01013f5:	89 55 14             	mov    %edx,0x14(%ebp)
f01013f8:	8b 30                	mov    (%eax),%esi
f01013fa:	89 75 e0             	mov    %esi,-0x20(%ebp)
f01013fd:	89 f0                	mov    %esi,%eax
f01013ff:	c1 f8 1f             	sar    $0x1f,%eax
f0101402:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0101405:	eb 16                	jmp    f010141d <vprintfmt+0x2df>
	else
		return va_arg(*ap, int);
f0101407:	8b 45 14             	mov    0x14(%ebp),%eax
f010140a:	8d 50 04             	lea    0x4(%eax),%edx
f010140d:	89 55 14             	mov    %edx,0x14(%ebp)
f0101410:	8b 30                	mov    (%eax),%esi
f0101412:	89 75 e0             	mov    %esi,-0x20(%ebp)
f0101415:	89 f0                	mov    %esi,%eax
f0101417:	c1 f8 1f             	sar    $0x1f,%eax
f010141a:	89 45 e4             	mov    %eax,-0x1c(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f010141d:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0101420:	8b 55 e4             	mov    -0x1c(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f0101423:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f0101428:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f010142c:	0f 89 80 00 00 00    	jns    f01014b2 <vprintfmt+0x374>
				putch('-', putdat);
f0101432:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101436:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f010143d:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f0101440:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0101443:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f0101446:	f7 d8                	neg    %eax
f0101448:	83 d2 00             	adc    $0x0,%edx
f010144b:	f7 da                	neg    %edx
			}
			base = 10;
f010144d:	b9 0a 00 00 00       	mov    $0xa,%ecx
f0101452:	eb 5e                	jmp    f01014b2 <vprintfmt+0x374>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f0101454:	8d 45 14             	lea    0x14(%ebp),%eax
f0101457:	e8 63 fc ff ff       	call   f01010bf <getuint>
			base = 10;
f010145c:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f0101461:	eb 4f                	jmp    f01014b2 <vprintfmt+0x374>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
				num = getuint(&ap,lflag);
f0101463:	8d 45 14             	lea    0x14(%ebp),%eax
f0101466:	e8 54 fc ff ff       	call   f01010bf <getuint>
			base = 8;
f010146b:	b9 08 00 00 00       	mov    $0x8,%ecx
			goto number;
f0101470:	eb 40                	jmp    f01014b2 <vprintfmt+0x374>
			//break;

		// pointer
		case 'p':
			putch('0', putdat);
f0101472:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101476:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f010147d:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f0101480:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101484:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f010148b:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f010148e:	8b 45 14             	mov    0x14(%ebp),%eax
f0101491:	8d 50 04             	lea    0x4(%eax),%edx
f0101494:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f0101497:	8b 00                	mov    (%eax),%eax
f0101499:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f010149e:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f01014a3:	eb 0d                	jmp    f01014b2 <vprintfmt+0x374>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f01014a5:	8d 45 14             	lea    0x14(%ebp),%eax
f01014a8:	e8 12 fc ff ff       	call   f01010bf <getuint>
			base = 16;
f01014ad:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f01014b2:	0f be 75 d8          	movsbl -0x28(%ebp),%esi
f01014b6:	89 74 24 10          	mov    %esi,0x10(%esp)
f01014ba:	8b 75 dc             	mov    -0x24(%ebp),%esi
f01014bd:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01014c1:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01014c5:	89 04 24             	mov    %eax,(%esp)
f01014c8:	89 54 24 04          	mov    %edx,0x4(%esp)
f01014cc:	89 fa                	mov    %edi,%edx
f01014ce:	8b 45 08             	mov    0x8(%ebp),%eax
f01014d1:	e8 fa fa ff ff       	call   f0100fd0 <printnum>
			break;
f01014d6:	e9 88 fc ff ff       	jmp    f0101163 <vprintfmt+0x25>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f01014db:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01014df:	89 04 24             	mov    %eax,(%esp)
f01014e2:	ff 55 08             	call   *0x8(%ebp)
			break;
f01014e5:	e9 79 fc ff ff       	jmp    f0101163 <vprintfmt+0x25>

		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f01014ea:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01014ee:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f01014f5:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f01014f8:	89 f3                	mov    %esi,%ebx
f01014fa:	eb 03                	jmp    f01014ff <vprintfmt+0x3c1>
f01014fc:	83 eb 01             	sub    $0x1,%ebx
f01014ff:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f0101503:	75 f7                	jne    f01014fc <vprintfmt+0x3be>
f0101505:	e9 59 fc ff ff       	jmp    f0101163 <vprintfmt+0x25>
				/* do nothing */;
			break;
		}
	}
}
f010150a:	83 c4 3c             	add    $0x3c,%esp
f010150d:	5b                   	pop    %ebx
f010150e:	5e                   	pop    %esi
f010150f:	5f                   	pop    %edi
f0101510:	5d                   	pop    %ebp
f0101511:	c3                   	ret    

f0101512 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0101512:	55                   	push   %ebp
f0101513:	89 e5                	mov    %esp,%ebp
f0101515:	83 ec 28             	sub    $0x28,%esp
f0101518:	8b 45 08             	mov    0x8(%ebp),%eax
f010151b:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f010151e:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0101521:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f0101525:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f0101528:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f010152f:	85 c0                	test   %eax,%eax
f0101531:	74 30                	je     f0101563 <vsnprintf+0x51>
f0101533:	85 d2                	test   %edx,%edx
f0101535:	7e 2c                	jle    f0101563 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f0101537:	8b 45 14             	mov    0x14(%ebp),%eax
f010153a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010153e:	8b 45 10             	mov    0x10(%ebp),%eax
f0101541:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101545:	8d 45 ec             	lea    -0x14(%ebp),%eax
f0101548:	89 44 24 04          	mov    %eax,0x4(%esp)
f010154c:	c7 04 24 f9 10 10 f0 	movl   $0xf01010f9,(%esp)
f0101553:	e8 e6 fb ff ff       	call   f010113e <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f0101558:	8b 45 ec             	mov    -0x14(%ebp),%eax
f010155b:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f010155e:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101561:	eb 05                	jmp    f0101568 <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f0101563:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f0101568:	c9                   	leave  
f0101569:	c3                   	ret    

f010156a <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f010156a:	55                   	push   %ebp
f010156b:	89 e5                	mov    %esp,%ebp
f010156d:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0101570:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f0101573:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101577:	8b 45 10             	mov    0x10(%ebp),%eax
f010157a:	89 44 24 08          	mov    %eax,0x8(%esp)
f010157e:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101581:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101585:	8b 45 08             	mov    0x8(%ebp),%eax
f0101588:	89 04 24             	mov    %eax,(%esp)
f010158b:	e8 82 ff ff ff       	call   f0101512 <vsnprintf>
	va_end(ap);

	return rc;
}
f0101590:	c9                   	leave  
f0101591:	c3                   	ret    
f0101592:	66 90                	xchg   %ax,%ax
f0101594:	66 90                	xchg   %ax,%ax
f0101596:	66 90                	xchg   %ax,%ax
f0101598:	66 90                	xchg   %ax,%ax
f010159a:	66 90                	xchg   %ax,%ax
f010159c:	66 90                	xchg   %ax,%ax
f010159e:	66 90                	xchg   %ax,%ax

f01015a0 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f01015a0:	55                   	push   %ebp
f01015a1:	89 e5                	mov    %esp,%ebp
f01015a3:	57                   	push   %edi
f01015a4:	56                   	push   %esi
f01015a5:	53                   	push   %ebx
f01015a6:	83 ec 1c             	sub    $0x1c,%esp
f01015a9:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f01015ac:	85 c0                	test   %eax,%eax
f01015ae:	74 10                	je     f01015c0 <readline+0x20>
		cprintf("%s", prompt);
f01015b0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01015b4:	c7 04 24 ed 22 10 f0 	movl   $0xf01022ed,(%esp)
f01015bb:	e8 39 f7 ff ff       	call   f0100cf9 <cprintf>

	i = 0;
	echoing = iscons(0);
f01015c0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01015c7:	e8 56 f0 ff ff       	call   f0100622 <iscons>
f01015cc:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f01015ce:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f01015d3:	e8 39 f0 ff ff       	call   f0100611 <getchar>
f01015d8:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f01015da:	85 c0                	test   %eax,%eax
f01015dc:	79 17                	jns    f01015f5 <readline+0x55>
			cprintf("read error: %e\n", c);
f01015de:	89 44 24 04          	mov    %eax,0x4(%esp)
f01015e2:	c7 04 24 d0 24 10 f0 	movl   $0xf01024d0,(%esp)
f01015e9:	e8 0b f7 ff ff       	call   f0100cf9 <cprintf>
			return NULL;
f01015ee:	b8 00 00 00 00       	mov    $0x0,%eax
f01015f3:	eb 6d                	jmp    f0101662 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f01015f5:	83 f8 7f             	cmp    $0x7f,%eax
f01015f8:	74 05                	je     f01015ff <readline+0x5f>
f01015fa:	83 f8 08             	cmp    $0x8,%eax
f01015fd:	75 19                	jne    f0101618 <readline+0x78>
f01015ff:	85 f6                	test   %esi,%esi
f0101601:	7e 15                	jle    f0101618 <readline+0x78>
			if (echoing)
f0101603:	85 ff                	test   %edi,%edi
f0101605:	74 0c                	je     f0101613 <readline+0x73>
				cputchar('\b');
f0101607:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f010160e:	e8 ee ef ff ff       	call   f0100601 <cputchar>
			i--;
f0101613:	83 ee 01             	sub    $0x1,%esi
f0101616:	eb bb                	jmp    f01015d3 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0101618:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f010161e:	7f 1c                	jg     f010163c <readline+0x9c>
f0101620:	83 fb 1f             	cmp    $0x1f,%ebx
f0101623:	7e 17                	jle    f010163c <readline+0x9c>
			if (echoing)
f0101625:	85 ff                	test   %edi,%edi
f0101627:	74 08                	je     f0101631 <readline+0x91>
				cputchar(c);
f0101629:	89 1c 24             	mov    %ebx,(%esp)
f010162c:	e8 d0 ef ff ff       	call   f0100601 <cputchar>
			buf[i++] = c;
f0101631:	88 9e 60 35 11 f0    	mov    %bl,-0xfeecaa0(%esi)
f0101637:	8d 76 01             	lea    0x1(%esi),%esi
f010163a:	eb 97                	jmp    f01015d3 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f010163c:	83 fb 0d             	cmp    $0xd,%ebx
f010163f:	74 05                	je     f0101646 <readline+0xa6>
f0101641:	83 fb 0a             	cmp    $0xa,%ebx
f0101644:	75 8d                	jne    f01015d3 <readline+0x33>
			if (echoing)
f0101646:	85 ff                	test   %edi,%edi
f0101648:	74 0c                	je     f0101656 <readline+0xb6>
				cputchar('\n');
f010164a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0101651:	e8 ab ef ff ff       	call   f0100601 <cputchar>
			buf[i] = 0;
f0101656:	c6 86 60 35 11 f0 00 	movb   $0x0,-0xfeecaa0(%esi)
			return buf;
f010165d:	b8 60 35 11 f0       	mov    $0xf0113560,%eax
		}
	}
}
f0101662:	83 c4 1c             	add    $0x1c,%esp
f0101665:	5b                   	pop    %ebx
f0101666:	5e                   	pop    %esi
f0101667:	5f                   	pop    %edi
f0101668:	5d                   	pop    %ebp
f0101669:	c3                   	ret    
f010166a:	66 90                	xchg   %ax,%ax
f010166c:	66 90                	xchg   %ax,%ax
f010166e:	66 90                	xchg   %ax,%ax

f0101670 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0101670:	55                   	push   %ebp
f0101671:	89 e5                	mov    %esp,%ebp
f0101673:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0101676:	b8 00 00 00 00       	mov    $0x0,%eax
f010167b:	eb 03                	jmp    f0101680 <strlen+0x10>
		n++;
f010167d:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f0101680:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0101684:	75 f7                	jne    f010167d <strlen+0xd>
		n++;
	return n;
}
f0101686:	5d                   	pop    %ebp
f0101687:	c3                   	ret    

f0101688 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0101688:	55                   	push   %ebp
f0101689:	89 e5                	mov    %esp,%ebp
f010168b:	8b 4d 08             	mov    0x8(%ebp),%ecx
f010168e:	8b 55 0c             	mov    0xc(%ebp),%edx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0101691:	b8 00 00 00 00       	mov    $0x0,%eax
f0101696:	eb 03                	jmp    f010169b <strnlen+0x13>
		n++;
f0101698:	83 c0 01             	add    $0x1,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010169b:	39 d0                	cmp    %edx,%eax
f010169d:	74 06                	je     f01016a5 <strnlen+0x1d>
f010169f:	80 3c 01 00          	cmpb   $0x0,(%ecx,%eax,1)
f01016a3:	75 f3                	jne    f0101698 <strnlen+0x10>
		n++;
	return n;
}
f01016a5:	5d                   	pop    %ebp
f01016a6:	c3                   	ret    

f01016a7 <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f01016a7:	55                   	push   %ebp
f01016a8:	89 e5                	mov    %esp,%ebp
f01016aa:	53                   	push   %ebx
f01016ab:	8b 45 08             	mov    0x8(%ebp),%eax
f01016ae:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f01016b1:	89 c2                	mov    %eax,%edx
f01016b3:	83 c2 01             	add    $0x1,%edx
f01016b6:	83 c1 01             	add    $0x1,%ecx
f01016b9:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f01016bd:	88 5a ff             	mov    %bl,-0x1(%edx)
f01016c0:	84 db                	test   %bl,%bl
f01016c2:	75 ef                	jne    f01016b3 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f01016c4:	5b                   	pop    %ebx
f01016c5:	5d                   	pop    %ebp
f01016c6:	c3                   	ret    

f01016c7 <strcat>:

char *
strcat(char *dst, const char *src)
{
f01016c7:	55                   	push   %ebp
f01016c8:	89 e5                	mov    %esp,%ebp
f01016ca:	53                   	push   %ebx
f01016cb:	83 ec 08             	sub    $0x8,%esp
f01016ce:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f01016d1:	89 1c 24             	mov    %ebx,(%esp)
f01016d4:	e8 97 ff ff ff       	call   f0101670 <strlen>
	strcpy(dst + len, src);
f01016d9:	8b 55 0c             	mov    0xc(%ebp),%edx
f01016dc:	89 54 24 04          	mov    %edx,0x4(%esp)
f01016e0:	01 d8                	add    %ebx,%eax
f01016e2:	89 04 24             	mov    %eax,(%esp)
f01016e5:	e8 bd ff ff ff       	call   f01016a7 <strcpy>
	return dst;
}
f01016ea:	89 d8                	mov    %ebx,%eax
f01016ec:	83 c4 08             	add    $0x8,%esp
f01016ef:	5b                   	pop    %ebx
f01016f0:	5d                   	pop    %ebp
f01016f1:	c3                   	ret    

f01016f2 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f01016f2:	55                   	push   %ebp
f01016f3:	89 e5                	mov    %esp,%ebp
f01016f5:	56                   	push   %esi
f01016f6:	53                   	push   %ebx
f01016f7:	8b 75 08             	mov    0x8(%ebp),%esi
f01016fa:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01016fd:	89 f3                	mov    %esi,%ebx
f01016ff:	03 5d 10             	add    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0101702:	89 f2                	mov    %esi,%edx
f0101704:	eb 0f                	jmp    f0101715 <strncpy+0x23>
		*dst++ = *src;
f0101706:	83 c2 01             	add    $0x1,%edx
f0101709:	0f b6 01             	movzbl (%ecx),%eax
f010170c:	88 42 ff             	mov    %al,-0x1(%edx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f010170f:	80 39 01             	cmpb   $0x1,(%ecx)
f0101712:	83 d9 ff             	sbb    $0xffffffff,%ecx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0101715:	39 da                	cmp    %ebx,%edx
f0101717:	75 ed                	jne    f0101706 <strncpy+0x14>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f0101719:	89 f0                	mov    %esi,%eax
f010171b:	5b                   	pop    %ebx
f010171c:	5e                   	pop    %esi
f010171d:	5d                   	pop    %ebp
f010171e:	c3                   	ret    

f010171f <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f010171f:	55                   	push   %ebp
f0101720:	89 e5                	mov    %esp,%ebp
f0101722:	56                   	push   %esi
f0101723:	53                   	push   %ebx
f0101724:	8b 75 08             	mov    0x8(%ebp),%esi
f0101727:	8b 55 0c             	mov    0xc(%ebp),%edx
f010172a:	8b 4d 10             	mov    0x10(%ebp),%ecx
f010172d:	89 f0                	mov    %esi,%eax
f010172f:	8d 5c 0e ff          	lea    -0x1(%esi,%ecx,1),%ebx
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0101733:	85 c9                	test   %ecx,%ecx
f0101735:	75 0b                	jne    f0101742 <strlcpy+0x23>
f0101737:	eb 1d                	jmp    f0101756 <strlcpy+0x37>
		while (--size > 0 && *src != '\0')
			*dst++ = *src++;
f0101739:	83 c0 01             	add    $0x1,%eax
f010173c:	83 c2 01             	add    $0x1,%edx
f010173f:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0101742:	39 d8                	cmp    %ebx,%eax
f0101744:	74 0b                	je     f0101751 <strlcpy+0x32>
f0101746:	0f b6 0a             	movzbl (%edx),%ecx
f0101749:	84 c9                	test   %cl,%cl
f010174b:	75 ec                	jne    f0101739 <strlcpy+0x1a>
f010174d:	89 c2                	mov    %eax,%edx
f010174f:	eb 02                	jmp    f0101753 <strlcpy+0x34>
f0101751:	89 c2                	mov    %eax,%edx
			*dst++ = *src++;
		*dst = '\0';
f0101753:	c6 02 00             	movb   $0x0,(%edx)
	}
	return dst - dst_in;
f0101756:	29 f0                	sub    %esi,%eax
}
f0101758:	5b                   	pop    %ebx
f0101759:	5e                   	pop    %esi
f010175a:	5d                   	pop    %ebp
f010175b:	c3                   	ret    

f010175c <strcmp>:

int
strcmp(const char *p, const char *q)
{
f010175c:	55                   	push   %ebp
f010175d:	89 e5                	mov    %esp,%ebp
f010175f:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0101762:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f0101765:	eb 06                	jmp    f010176d <strcmp+0x11>
		p++, q++;
f0101767:	83 c1 01             	add    $0x1,%ecx
f010176a:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f010176d:	0f b6 01             	movzbl (%ecx),%eax
f0101770:	84 c0                	test   %al,%al
f0101772:	74 04                	je     f0101778 <strcmp+0x1c>
f0101774:	3a 02                	cmp    (%edx),%al
f0101776:	74 ef                	je     f0101767 <strcmp+0xb>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f0101778:	0f b6 c0             	movzbl %al,%eax
f010177b:	0f b6 12             	movzbl (%edx),%edx
f010177e:	29 d0                	sub    %edx,%eax
}
f0101780:	5d                   	pop    %ebp
f0101781:	c3                   	ret    

f0101782 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0101782:	55                   	push   %ebp
f0101783:	89 e5                	mov    %esp,%ebp
f0101785:	53                   	push   %ebx
f0101786:	8b 45 08             	mov    0x8(%ebp),%eax
f0101789:	8b 55 0c             	mov    0xc(%ebp),%edx
f010178c:	89 c3                	mov    %eax,%ebx
f010178e:	03 5d 10             	add    0x10(%ebp),%ebx
	while (n > 0 && *p && *p == *q)
f0101791:	eb 06                	jmp    f0101799 <strncmp+0x17>
		n--, p++, q++;
f0101793:	83 c0 01             	add    $0x1,%eax
f0101796:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f0101799:	39 d8                	cmp    %ebx,%eax
f010179b:	74 15                	je     f01017b2 <strncmp+0x30>
f010179d:	0f b6 08             	movzbl (%eax),%ecx
f01017a0:	84 c9                	test   %cl,%cl
f01017a2:	74 04                	je     f01017a8 <strncmp+0x26>
f01017a4:	3a 0a                	cmp    (%edx),%cl
f01017a6:	74 eb                	je     f0101793 <strncmp+0x11>
		n--, p++, q++;
	if (n == 0)
		return 0;
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f01017a8:	0f b6 00             	movzbl (%eax),%eax
f01017ab:	0f b6 12             	movzbl (%edx),%edx
f01017ae:	29 d0                	sub    %edx,%eax
f01017b0:	eb 05                	jmp    f01017b7 <strncmp+0x35>
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
		n--, p++, q++;
	if (n == 0)
		return 0;
f01017b2:	b8 00 00 00 00       	mov    $0x0,%eax
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
}
f01017b7:	5b                   	pop    %ebx
f01017b8:	5d                   	pop    %ebp
f01017b9:	c3                   	ret    

f01017ba <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f01017ba:	55                   	push   %ebp
f01017bb:	89 e5                	mov    %esp,%ebp
f01017bd:	8b 45 08             	mov    0x8(%ebp),%eax
f01017c0:	0f b6 4d 0c          	movzbl 0xc(%ebp),%ecx
	for (; *s; s++)
f01017c4:	eb 07                	jmp    f01017cd <strchr+0x13>
		if (*s == c)
f01017c6:	38 ca                	cmp    %cl,%dl
f01017c8:	74 0f                	je     f01017d9 <strchr+0x1f>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f01017ca:	83 c0 01             	add    $0x1,%eax
f01017cd:	0f b6 10             	movzbl (%eax),%edx
f01017d0:	84 d2                	test   %dl,%dl
f01017d2:	75 f2                	jne    f01017c6 <strchr+0xc>
		if (*s == c)
			return (char *) s;
	return 0;
f01017d4:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01017d9:	5d                   	pop    %ebp
f01017da:	c3                   	ret    

f01017db <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f01017db:	55                   	push   %ebp
f01017dc:	89 e5                	mov    %esp,%ebp
f01017de:	8b 45 08             	mov    0x8(%ebp),%eax
f01017e1:	0f b6 4d 0c          	movzbl 0xc(%ebp),%ecx
	for (; *s; s++)
f01017e5:	eb 07                	jmp    f01017ee <strfind+0x13>
		if (*s == c)
f01017e7:	38 ca                	cmp    %cl,%dl
f01017e9:	74 0a                	je     f01017f5 <strfind+0x1a>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f01017eb:	83 c0 01             	add    $0x1,%eax
f01017ee:	0f b6 10             	movzbl (%eax),%edx
f01017f1:	84 d2                	test   %dl,%dl
f01017f3:	75 f2                	jne    f01017e7 <strfind+0xc>
		if (*s == c)
			break;
	return (char *) s;
}
f01017f5:	5d                   	pop    %ebp
f01017f6:	c3                   	ret    

f01017f7 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f01017f7:	55                   	push   %ebp
f01017f8:	89 e5                	mov    %esp,%ebp
f01017fa:	57                   	push   %edi
f01017fb:	56                   	push   %esi
f01017fc:	53                   	push   %ebx
f01017fd:	8b 7d 08             	mov    0x8(%ebp),%edi
f0101800:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f0101803:	85 c9                	test   %ecx,%ecx
f0101805:	74 36                	je     f010183d <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f0101807:	f7 c7 03 00 00 00    	test   $0x3,%edi
f010180d:	75 28                	jne    f0101837 <memset+0x40>
f010180f:	f6 c1 03             	test   $0x3,%cl
f0101812:	75 23                	jne    f0101837 <memset+0x40>
		c &= 0xFF;
f0101814:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f0101818:	89 d3                	mov    %edx,%ebx
f010181a:	c1 e3 08             	shl    $0x8,%ebx
f010181d:	89 d6                	mov    %edx,%esi
f010181f:	c1 e6 18             	shl    $0x18,%esi
f0101822:	89 d0                	mov    %edx,%eax
f0101824:	c1 e0 10             	shl    $0x10,%eax
f0101827:	09 f0                	or     %esi,%eax
f0101829:	09 c2                	or     %eax,%edx
f010182b:	89 d0                	mov    %edx,%eax
f010182d:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f010182f:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0101832:	fc                   	cld    
f0101833:	f3 ab                	rep stos %eax,%es:(%edi)
f0101835:	eb 06                	jmp    f010183d <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0101837:	8b 45 0c             	mov    0xc(%ebp),%eax
f010183a:	fc                   	cld    
f010183b:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f010183d:	89 f8                	mov    %edi,%eax
f010183f:	5b                   	pop    %ebx
f0101840:	5e                   	pop    %esi
f0101841:	5f                   	pop    %edi
f0101842:	5d                   	pop    %ebp
f0101843:	c3                   	ret    

f0101844 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0101844:	55                   	push   %ebp
f0101845:	89 e5                	mov    %esp,%ebp
f0101847:	57                   	push   %edi
f0101848:	56                   	push   %esi
f0101849:	8b 45 08             	mov    0x8(%ebp),%eax
f010184c:	8b 75 0c             	mov    0xc(%ebp),%esi
f010184f:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;

	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0101852:	39 c6                	cmp    %eax,%esi
f0101854:	73 35                	jae    f010188b <memmove+0x47>
f0101856:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0101859:	39 d0                	cmp    %edx,%eax
f010185b:	73 2e                	jae    f010188b <memmove+0x47>
		s += n;
		d += n;
f010185d:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0101860:	89 d6                	mov    %edx,%esi
f0101862:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0101864:	f7 c6 03 00 00 00    	test   $0x3,%esi
f010186a:	75 13                	jne    f010187f <memmove+0x3b>
f010186c:	f6 c1 03             	test   $0x3,%cl
f010186f:	75 0e                	jne    f010187f <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0101871:	83 ef 04             	sub    $0x4,%edi
f0101874:	8d 72 fc             	lea    -0x4(%edx),%esi
f0101877:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f010187a:	fd                   	std    
f010187b:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f010187d:	eb 09                	jmp    f0101888 <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f010187f:	83 ef 01             	sub    $0x1,%edi
f0101882:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0101885:	fd                   	std    
f0101886:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0101888:	fc                   	cld    
f0101889:	eb 1d                	jmp    f01018a8 <memmove+0x64>
f010188b:	89 f2                	mov    %esi,%edx
f010188d:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f010188f:	f6 c2 03             	test   $0x3,%dl
f0101892:	75 0f                	jne    f01018a3 <memmove+0x5f>
f0101894:	f6 c1 03             	test   $0x3,%cl
f0101897:	75 0a                	jne    f01018a3 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f0101899:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f010189c:	89 c7                	mov    %eax,%edi
f010189e:	fc                   	cld    
f010189f:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f01018a1:	eb 05                	jmp    f01018a8 <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f01018a3:	89 c7                	mov    %eax,%edi
f01018a5:	fc                   	cld    
f01018a6:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f01018a8:	5e                   	pop    %esi
f01018a9:	5f                   	pop    %edi
f01018aa:	5d                   	pop    %ebp
f01018ab:	c3                   	ret    

f01018ac <memcpy>:
}
#endif

void *
memcpy(void *dst, const void *src, size_t n)
{
f01018ac:	55                   	push   %ebp
f01018ad:	89 e5                	mov    %esp,%ebp
f01018af:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f01018b2:	8b 45 10             	mov    0x10(%ebp),%eax
f01018b5:	89 44 24 08          	mov    %eax,0x8(%esp)
f01018b9:	8b 45 0c             	mov    0xc(%ebp),%eax
f01018bc:	89 44 24 04          	mov    %eax,0x4(%esp)
f01018c0:	8b 45 08             	mov    0x8(%ebp),%eax
f01018c3:	89 04 24             	mov    %eax,(%esp)
f01018c6:	e8 79 ff ff ff       	call   f0101844 <memmove>
}
f01018cb:	c9                   	leave  
f01018cc:	c3                   	ret    

f01018cd <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f01018cd:	55                   	push   %ebp
f01018ce:	89 e5                	mov    %esp,%ebp
f01018d0:	56                   	push   %esi
f01018d1:	53                   	push   %ebx
f01018d2:	8b 55 08             	mov    0x8(%ebp),%edx
f01018d5:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01018d8:	89 d6                	mov    %edx,%esi
f01018da:	03 75 10             	add    0x10(%ebp),%esi
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01018dd:	eb 1a                	jmp    f01018f9 <memcmp+0x2c>
		if (*s1 != *s2)
f01018df:	0f b6 02             	movzbl (%edx),%eax
f01018e2:	0f b6 19             	movzbl (%ecx),%ebx
f01018e5:	38 d8                	cmp    %bl,%al
f01018e7:	74 0a                	je     f01018f3 <memcmp+0x26>
			return (int) *s1 - (int) *s2;
f01018e9:	0f b6 c0             	movzbl %al,%eax
f01018ec:	0f b6 db             	movzbl %bl,%ebx
f01018ef:	29 d8                	sub    %ebx,%eax
f01018f1:	eb 0f                	jmp    f0101902 <memcmp+0x35>
		s1++, s2++;
f01018f3:	83 c2 01             	add    $0x1,%edx
f01018f6:	83 c1 01             	add    $0x1,%ecx
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01018f9:	39 f2                	cmp    %esi,%edx
f01018fb:	75 e2                	jne    f01018df <memcmp+0x12>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f01018fd:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0101902:	5b                   	pop    %ebx
f0101903:	5e                   	pop    %esi
f0101904:	5d                   	pop    %ebp
f0101905:	c3                   	ret    

f0101906 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f0101906:	55                   	push   %ebp
f0101907:	89 e5                	mov    %esp,%ebp
f0101909:	8b 45 08             	mov    0x8(%ebp),%eax
f010190c:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	const void *ends = (const char *) s + n;
f010190f:	89 c2                	mov    %eax,%edx
f0101911:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0101914:	eb 07                	jmp    f010191d <memfind+0x17>
		if (*(const unsigned char *) s == (unsigned char) c)
f0101916:	38 08                	cmp    %cl,(%eax)
f0101918:	74 07                	je     f0101921 <memfind+0x1b>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f010191a:	83 c0 01             	add    $0x1,%eax
f010191d:	39 d0                	cmp    %edx,%eax
f010191f:	72 f5                	jb     f0101916 <memfind+0x10>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f0101921:	5d                   	pop    %ebp
f0101922:	c3                   	ret    

f0101923 <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f0101923:	55                   	push   %ebp
f0101924:	89 e5                	mov    %esp,%ebp
f0101926:	57                   	push   %edi
f0101927:	56                   	push   %esi
f0101928:	53                   	push   %ebx
f0101929:	8b 55 08             	mov    0x8(%ebp),%edx
f010192c:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010192f:	eb 03                	jmp    f0101934 <strtol+0x11>
		s++;
f0101931:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0101934:	0f b6 0a             	movzbl (%edx),%ecx
f0101937:	80 f9 09             	cmp    $0x9,%cl
f010193a:	74 f5                	je     f0101931 <strtol+0xe>
f010193c:	80 f9 20             	cmp    $0x20,%cl
f010193f:	74 f0                	je     f0101931 <strtol+0xe>
		s++;

	// plus/minus sign
	if (*s == '+')
f0101941:	80 f9 2b             	cmp    $0x2b,%cl
f0101944:	75 0a                	jne    f0101950 <strtol+0x2d>
		s++;
f0101946:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f0101949:	bf 00 00 00 00       	mov    $0x0,%edi
f010194e:	eb 11                	jmp    f0101961 <strtol+0x3e>
f0101950:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f0101955:	80 f9 2d             	cmp    $0x2d,%cl
f0101958:	75 07                	jne    f0101961 <strtol+0x3e>
		s++, neg = 1;
f010195a:	8d 52 01             	lea    0x1(%edx),%edx
f010195d:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0101961:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f0101966:	75 15                	jne    f010197d <strtol+0x5a>
f0101968:	80 3a 30             	cmpb   $0x30,(%edx)
f010196b:	75 10                	jne    f010197d <strtol+0x5a>
f010196d:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0101971:	75 0a                	jne    f010197d <strtol+0x5a>
		s += 2, base = 16;
f0101973:	83 c2 02             	add    $0x2,%edx
f0101976:	b8 10 00 00 00       	mov    $0x10,%eax
f010197b:	eb 10                	jmp    f010198d <strtol+0x6a>
	else if (base == 0 && s[0] == '0')
f010197d:	85 c0                	test   %eax,%eax
f010197f:	75 0c                	jne    f010198d <strtol+0x6a>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0101981:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0101983:	80 3a 30             	cmpb   $0x30,(%edx)
f0101986:	75 05                	jne    f010198d <strtol+0x6a>
		s++, base = 8;
f0101988:	83 c2 01             	add    $0x1,%edx
f010198b:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f010198d:	bb 00 00 00 00       	mov    $0x0,%ebx
f0101992:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f0101995:	0f b6 0a             	movzbl (%edx),%ecx
f0101998:	8d 71 d0             	lea    -0x30(%ecx),%esi
f010199b:	89 f0                	mov    %esi,%eax
f010199d:	3c 09                	cmp    $0x9,%al
f010199f:	77 08                	ja     f01019a9 <strtol+0x86>
			dig = *s - '0';
f01019a1:	0f be c9             	movsbl %cl,%ecx
f01019a4:	83 e9 30             	sub    $0x30,%ecx
f01019a7:	eb 20                	jmp    f01019c9 <strtol+0xa6>
		else if (*s >= 'a' && *s <= 'z')
f01019a9:	8d 71 9f             	lea    -0x61(%ecx),%esi
f01019ac:	89 f0                	mov    %esi,%eax
f01019ae:	3c 19                	cmp    $0x19,%al
f01019b0:	77 08                	ja     f01019ba <strtol+0x97>
			dig = *s - 'a' + 10;
f01019b2:	0f be c9             	movsbl %cl,%ecx
f01019b5:	83 e9 57             	sub    $0x57,%ecx
f01019b8:	eb 0f                	jmp    f01019c9 <strtol+0xa6>
		else if (*s >= 'A' && *s <= 'Z')
f01019ba:	8d 71 bf             	lea    -0x41(%ecx),%esi
f01019bd:	89 f0                	mov    %esi,%eax
f01019bf:	3c 19                	cmp    $0x19,%al
f01019c1:	77 16                	ja     f01019d9 <strtol+0xb6>
			dig = *s - 'A' + 10;
f01019c3:	0f be c9             	movsbl %cl,%ecx
f01019c6:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f01019c9:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f01019cc:	7d 0f                	jge    f01019dd <strtol+0xba>
			break;
		s++, val = (val * base) + dig;
f01019ce:	83 c2 01             	add    $0x1,%edx
f01019d1:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f01019d5:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f01019d7:	eb bc                	jmp    f0101995 <strtol+0x72>
f01019d9:	89 d8                	mov    %ebx,%eax
f01019db:	eb 02                	jmp    f01019df <strtol+0xbc>
f01019dd:	89 d8                	mov    %ebx,%eax

	if (endptr)
f01019df:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f01019e3:	74 05                	je     f01019ea <strtol+0xc7>
		*endptr = (char *) s;
f01019e5:	8b 75 0c             	mov    0xc(%ebp),%esi
f01019e8:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f01019ea:	f7 d8                	neg    %eax
f01019ec:	85 ff                	test   %edi,%edi
f01019ee:	0f 44 c3             	cmove  %ebx,%eax
}
f01019f1:	5b                   	pop    %ebx
f01019f2:	5e                   	pop    %esi
f01019f3:	5f                   	pop    %edi
f01019f4:	5d                   	pop    %ebp
f01019f5:	c3                   	ret    
f01019f6:	66 90                	xchg   %ax,%ax
f01019f8:	66 90                	xchg   %ax,%ax
f01019fa:	66 90                	xchg   %ax,%ax
f01019fc:	66 90                	xchg   %ax,%ax
f01019fe:	66 90                	xchg   %ax,%ax

f0101a00 <__udivdi3>:
f0101a00:	55                   	push   %ebp
f0101a01:	57                   	push   %edi
f0101a02:	56                   	push   %esi
f0101a03:	83 ec 0c             	sub    $0xc,%esp
f0101a06:	8b 44 24 28          	mov    0x28(%esp),%eax
f0101a0a:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f0101a0e:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f0101a12:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0101a16:	85 c0                	test   %eax,%eax
f0101a18:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101a1c:	89 ea                	mov    %ebp,%edx
f0101a1e:	89 0c 24             	mov    %ecx,(%esp)
f0101a21:	75 2d                	jne    f0101a50 <__udivdi3+0x50>
f0101a23:	39 e9                	cmp    %ebp,%ecx
f0101a25:	77 61                	ja     f0101a88 <__udivdi3+0x88>
f0101a27:	85 c9                	test   %ecx,%ecx
f0101a29:	89 ce                	mov    %ecx,%esi
f0101a2b:	75 0b                	jne    f0101a38 <__udivdi3+0x38>
f0101a2d:	b8 01 00 00 00       	mov    $0x1,%eax
f0101a32:	31 d2                	xor    %edx,%edx
f0101a34:	f7 f1                	div    %ecx
f0101a36:	89 c6                	mov    %eax,%esi
f0101a38:	31 d2                	xor    %edx,%edx
f0101a3a:	89 e8                	mov    %ebp,%eax
f0101a3c:	f7 f6                	div    %esi
f0101a3e:	89 c5                	mov    %eax,%ebp
f0101a40:	89 f8                	mov    %edi,%eax
f0101a42:	f7 f6                	div    %esi
f0101a44:	89 ea                	mov    %ebp,%edx
f0101a46:	83 c4 0c             	add    $0xc,%esp
f0101a49:	5e                   	pop    %esi
f0101a4a:	5f                   	pop    %edi
f0101a4b:	5d                   	pop    %ebp
f0101a4c:	c3                   	ret    
f0101a4d:	8d 76 00             	lea    0x0(%esi),%esi
f0101a50:	39 e8                	cmp    %ebp,%eax
f0101a52:	77 24                	ja     f0101a78 <__udivdi3+0x78>
f0101a54:	0f bd e8             	bsr    %eax,%ebp
f0101a57:	83 f5 1f             	xor    $0x1f,%ebp
f0101a5a:	75 3c                	jne    f0101a98 <__udivdi3+0x98>
f0101a5c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0101a60:	39 34 24             	cmp    %esi,(%esp)
f0101a63:	0f 86 9f 00 00 00    	jbe    f0101b08 <__udivdi3+0x108>
f0101a69:	39 d0                	cmp    %edx,%eax
f0101a6b:	0f 82 97 00 00 00    	jb     f0101b08 <__udivdi3+0x108>
f0101a71:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101a78:	31 d2                	xor    %edx,%edx
f0101a7a:	31 c0                	xor    %eax,%eax
f0101a7c:	83 c4 0c             	add    $0xc,%esp
f0101a7f:	5e                   	pop    %esi
f0101a80:	5f                   	pop    %edi
f0101a81:	5d                   	pop    %ebp
f0101a82:	c3                   	ret    
f0101a83:	90                   	nop
f0101a84:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101a88:	89 f8                	mov    %edi,%eax
f0101a8a:	f7 f1                	div    %ecx
f0101a8c:	31 d2                	xor    %edx,%edx
f0101a8e:	83 c4 0c             	add    $0xc,%esp
f0101a91:	5e                   	pop    %esi
f0101a92:	5f                   	pop    %edi
f0101a93:	5d                   	pop    %ebp
f0101a94:	c3                   	ret    
f0101a95:	8d 76 00             	lea    0x0(%esi),%esi
f0101a98:	89 e9                	mov    %ebp,%ecx
f0101a9a:	8b 3c 24             	mov    (%esp),%edi
f0101a9d:	d3 e0                	shl    %cl,%eax
f0101a9f:	89 c6                	mov    %eax,%esi
f0101aa1:	b8 20 00 00 00       	mov    $0x20,%eax
f0101aa6:	29 e8                	sub    %ebp,%eax
f0101aa8:	89 c1                	mov    %eax,%ecx
f0101aaa:	d3 ef                	shr    %cl,%edi
f0101aac:	89 e9                	mov    %ebp,%ecx
f0101aae:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0101ab2:	8b 3c 24             	mov    (%esp),%edi
f0101ab5:	09 74 24 08          	or     %esi,0x8(%esp)
f0101ab9:	89 d6                	mov    %edx,%esi
f0101abb:	d3 e7                	shl    %cl,%edi
f0101abd:	89 c1                	mov    %eax,%ecx
f0101abf:	89 3c 24             	mov    %edi,(%esp)
f0101ac2:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0101ac6:	d3 ee                	shr    %cl,%esi
f0101ac8:	89 e9                	mov    %ebp,%ecx
f0101aca:	d3 e2                	shl    %cl,%edx
f0101acc:	89 c1                	mov    %eax,%ecx
f0101ace:	d3 ef                	shr    %cl,%edi
f0101ad0:	09 d7                	or     %edx,%edi
f0101ad2:	89 f2                	mov    %esi,%edx
f0101ad4:	89 f8                	mov    %edi,%eax
f0101ad6:	f7 74 24 08          	divl   0x8(%esp)
f0101ada:	89 d6                	mov    %edx,%esi
f0101adc:	89 c7                	mov    %eax,%edi
f0101ade:	f7 24 24             	mull   (%esp)
f0101ae1:	39 d6                	cmp    %edx,%esi
f0101ae3:	89 14 24             	mov    %edx,(%esp)
f0101ae6:	72 30                	jb     f0101b18 <__udivdi3+0x118>
f0101ae8:	8b 54 24 04          	mov    0x4(%esp),%edx
f0101aec:	89 e9                	mov    %ebp,%ecx
f0101aee:	d3 e2                	shl    %cl,%edx
f0101af0:	39 c2                	cmp    %eax,%edx
f0101af2:	73 05                	jae    f0101af9 <__udivdi3+0xf9>
f0101af4:	3b 34 24             	cmp    (%esp),%esi
f0101af7:	74 1f                	je     f0101b18 <__udivdi3+0x118>
f0101af9:	89 f8                	mov    %edi,%eax
f0101afb:	31 d2                	xor    %edx,%edx
f0101afd:	e9 7a ff ff ff       	jmp    f0101a7c <__udivdi3+0x7c>
f0101b02:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0101b08:	31 d2                	xor    %edx,%edx
f0101b0a:	b8 01 00 00 00       	mov    $0x1,%eax
f0101b0f:	e9 68 ff ff ff       	jmp    f0101a7c <__udivdi3+0x7c>
f0101b14:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101b18:	8d 47 ff             	lea    -0x1(%edi),%eax
f0101b1b:	31 d2                	xor    %edx,%edx
f0101b1d:	83 c4 0c             	add    $0xc,%esp
f0101b20:	5e                   	pop    %esi
f0101b21:	5f                   	pop    %edi
f0101b22:	5d                   	pop    %ebp
f0101b23:	c3                   	ret    
f0101b24:	66 90                	xchg   %ax,%ax
f0101b26:	66 90                	xchg   %ax,%ax
f0101b28:	66 90                	xchg   %ax,%ax
f0101b2a:	66 90                	xchg   %ax,%ax
f0101b2c:	66 90                	xchg   %ax,%ax
f0101b2e:	66 90                	xchg   %ax,%ax

f0101b30 <__umoddi3>:
f0101b30:	55                   	push   %ebp
f0101b31:	57                   	push   %edi
f0101b32:	56                   	push   %esi
f0101b33:	83 ec 14             	sub    $0x14,%esp
f0101b36:	8b 44 24 28          	mov    0x28(%esp),%eax
f0101b3a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0101b3e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0101b42:	89 c7                	mov    %eax,%edi
f0101b44:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101b48:	8b 44 24 30          	mov    0x30(%esp),%eax
f0101b4c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0101b50:	89 34 24             	mov    %esi,(%esp)
f0101b53:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0101b57:	85 c0                	test   %eax,%eax
f0101b59:	89 c2                	mov    %eax,%edx
f0101b5b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0101b5f:	75 17                	jne    f0101b78 <__umoddi3+0x48>
f0101b61:	39 fe                	cmp    %edi,%esi
f0101b63:	76 4b                	jbe    f0101bb0 <__umoddi3+0x80>
f0101b65:	89 c8                	mov    %ecx,%eax
f0101b67:	89 fa                	mov    %edi,%edx
f0101b69:	f7 f6                	div    %esi
f0101b6b:	89 d0                	mov    %edx,%eax
f0101b6d:	31 d2                	xor    %edx,%edx
f0101b6f:	83 c4 14             	add    $0x14,%esp
f0101b72:	5e                   	pop    %esi
f0101b73:	5f                   	pop    %edi
f0101b74:	5d                   	pop    %ebp
f0101b75:	c3                   	ret    
f0101b76:	66 90                	xchg   %ax,%ax
f0101b78:	39 f8                	cmp    %edi,%eax
f0101b7a:	77 54                	ja     f0101bd0 <__umoddi3+0xa0>
f0101b7c:	0f bd e8             	bsr    %eax,%ebp
f0101b7f:	83 f5 1f             	xor    $0x1f,%ebp
f0101b82:	75 5c                	jne    f0101be0 <__umoddi3+0xb0>
f0101b84:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0101b88:	39 3c 24             	cmp    %edi,(%esp)
f0101b8b:	0f 87 e7 00 00 00    	ja     f0101c78 <__umoddi3+0x148>
f0101b91:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0101b95:	29 f1                	sub    %esi,%ecx
f0101b97:	19 c7                	sbb    %eax,%edi
f0101b99:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0101b9d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0101ba1:	8b 44 24 08          	mov    0x8(%esp),%eax
f0101ba5:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0101ba9:	83 c4 14             	add    $0x14,%esp
f0101bac:	5e                   	pop    %esi
f0101bad:	5f                   	pop    %edi
f0101bae:	5d                   	pop    %ebp
f0101baf:	c3                   	ret    
f0101bb0:	85 f6                	test   %esi,%esi
f0101bb2:	89 f5                	mov    %esi,%ebp
f0101bb4:	75 0b                	jne    f0101bc1 <__umoddi3+0x91>
f0101bb6:	b8 01 00 00 00       	mov    $0x1,%eax
f0101bbb:	31 d2                	xor    %edx,%edx
f0101bbd:	f7 f6                	div    %esi
f0101bbf:	89 c5                	mov    %eax,%ebp
f0101bc1:	8b 44 24 04          	mov    0x4(%esp),%eax
f0101bc5:	31 d2                	xor    %edx,%edx
f0101bc7:	f7 f5                	div    %ebp
f0101bc9:	89 c8                	mov    %ecx,%eax
f0101bcb:	f7 f5                	div    %ebp
f0101bcd:	eb 9c                	jmp    f0101b6b <__umoddi3+0x3b>
f0101bcf:	90                   	nop
f0101bd0:	89 c8                	mov    %ecx,%eax
f0101bd2:	89 fa                	mov    %edi,%edx
f0101bd4:	83 c4 14             	add    $0x14,%esp
f0101bd7:	5e                   	pop    %esi
f0101bd8:	5f                   	pop    %edi
f0101bd9:	5d                   	pop    %ebp
f0101bda:	c3                   	ret    
f0101bdb:	90                   	nop
f0101bdc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101be0:	8b 04 24             	mov    (%esp),%eax
f0101be3:	be 20 00 00 00       	mov    $0x20,%esi
f0101be8:	89 e9                	mov    %ebp,%ecx
f0101bea:	29 ee                	sub    %ebp,%esi
f0101bec:	d3 e2                	shl    %cl,%edx
f0101bee:	89 f1                	mov    %esi,%ecx
f0101bf0:	d3 e8                	shr    %cl,%eax
f0101bf2:	89 e9                	mov    %ebp,%ecx
f0101bf4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101bf8:	8b 04 24             	mov    (%esp),%eax
f0101bfb:	09 54 24 04          	or     %edx,0x4(%esp)
f0101bff:	89 fa                	mov    %edi,%edx
f0101c01:	d3 e0                	shl    %cl,%eax
f0101c03:	89 f1                	mov    %esi,%ecx
f0101c05:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101c09:	8b 44 24 10          	mov    0x10(%esp),%eax
f0101c0d:	d3 ea                	shr    %cl,%edx
f0101c0f:	89 e9                	mov    %ebp,%ecx
f0101c11:	d3 e7                	shl    %cl,%edi
f0101c13:	89 f1                	mov    %esi,%ecx
f0101c15:	d3 e8                	shr    %cl,%eax
f0101c17:	89 e9                	mov    %ebp,%ecx
f0101c19:	09 f8                	or     %edi,%eax
f0101c1b:	8b 7c 24 10          	mov    0x10(%esp),%edi
f0101c1f:	f7 74 24 04          	divl   0x4(%esp)
f0101c23:	d3 e7                	shl    %cl,%edi
f0101c25:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0101c29:	89 d7                	mov    %edx,%edi
f0101c2b:	f7 64 24 08          	mull   0x8(%esp)
f0101c2f:	39 d7                	cmp    %edx,%edi
f0101c31:	89 c1                	mov    %eax,%ecx
f0101c33:	89 14 24             	mov    %edx,(%esp)
f0101c36:	72 2c                	jb     f0101c64 <__umoddi3+0x134>
f0101c38:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f0101c3c:	72 22                	jb     f0101c60 <__umoddi3+0x130>
f0101c3e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0101c42:	29 c8                	sub    %ecx,%eax
f0101c44:	19 d7                	sbb    %edx,%edi
f0101c46:	89 e9                	mov    %ebp,%ecx
f0101c48:	89 fa                	mov    %edi,%edx
f0101c4a:	d3 e8                	shr    %cl,%eax
f0101c4c:	89 f1                	mov    %esi,%ecx
f0101c4e:	d3 e2                	shl    %cl,%edx
f0101c50:	89 e9                	mov    %ebp,%ecx
f0101c52:	d3 ef                	shr    %cl,%edi
f0101c54:	09 d0                	or     %edx,%eax
f0101c56:	89 fa                	mov    %edi,%edx
f0101c58:	83 c4 14             	add    $0x14,%esp
f0101c5b:	5e                   	pop    %esi
f0101c5c:	5f                   	pop    %edi
f0101c5d:	5d                   	pop    %ebp
f0101c5e:	c3                   	ret    
f0101c5f:	90                   	nop
f0101c60:	39 d7                	cmp    %edx,%edi
f0101c62:	75 da                	jne    f0101c3e <__umoddi3+0x10e>
f0101c64:	8b 14 24             	mov    (%esp),%edx
f0101c67:	89 c1                	mov    %eax,%ecx
f0101c69:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f0101c6d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0101c71:	eb cb                	jmp    f0101c3e <__umoddi3+0x10e>
f0101c73:	90                   	nop
f0101c74:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101c78:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f0101c7c:	0f 82 0f ff ff ff    	jb     f0101b91 <__umoddi3+0x61>
f0101c82:	e9 1a ff ff ff       	jmp    f0101ba1 <__umoddi3+0x71>
