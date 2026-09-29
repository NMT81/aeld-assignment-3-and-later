# FAULTY OOPS

### KERNEL LOG
```
Unable to handle kernel NULL pointer dereference at virtual address 0000000000000000
Mem abort info:
  ESR = 0x0000000096000044
  EC = 0x25: DABT (current EL), IL = 32 bits
  SET = 0, FnV = 0
  EA = 0, S1PTW = 0
  FSC = 0x04: level 0 translation fault
Data abort info:
  ISV = 0, ISS = 0x00000044, ISS2 = 0x00000000
  CM = 0, WnR = 1, TnD = 0, TagAccess = 0
  GCS = 0, Overlay = 0, DirtyBit = 0, Xs = 0
user pgtable: 4k pages, 48-bit VAs, pgdp=0000000041bd9000
[0000000000000000] pgd=0000000000000000, p4d=0000000000000000
Internal error: Oops: 0000000096000044 [#3] SMP
Modules linked in: hello(O) faulty(O) scull(O)
CPU: 0 UID: 0 PID: 158 Comm: sh Tainted: G      D    O       6.12.27 #1
Tainted: [D]=DIE, [O]=OOT_MODULE
Hardware name: linux,dummy-virt (DT)
pstate: 80000005 (Nzcv daif -PAN -UAO -TCO -DIT -SSBS BTYPE=--)
pc : faulty_write+0x8/0x10 [faulty]
lr : vfs_write+0xb4/0x38c
sp : ffff800080eb3d30
x29: ffff800080eb3da0 x28: ffff000001b52e80 x27: 0000000000000000
x26: 0000000000000000 x25: 0000000000000000 x24: 0000000000000000
x23: 0000000040000000 x22: 000000000000000c x21: 0000aaaae2337bf0
x20: 0000aaaae2337bf0 x19: ffff000001bd2cc0 x18: 0000000000000000
x17: 0000000000000000 x16: 0000000000000000 x15: 0000000000000000
x14: 0000000000000000 x13: 0000000000000000 x12: 0000000000000000
x11: 0000000000000000 x10: 0000000000000000 x9 : 0000000000000000
x8 : 0000000000000000 x7 : 0000000000000000 x6 : 0000000000000000
x5 : 0000000000000000 x4 : ffff800078c89000 x3 : ffff800080eb3dc0
x2 : 000000000000000c x1 : 0000000000000000 x0 : 0000000000000000
Call trace:
 faulty_write+0x8/0x10 [faulty]
 ksys_write+0x74/0x10c
 __arm64_sys_write+0x1c/0x28
 invoke_syscall+0x54/0x11c
 el0_svc_common.constprop.0+0x40/0xe0
 do_el0_svc+0x1c/0x28
 el0_svc+0x30/0xcc
 el0t_64_sync_handler+0x120/0x12c
 el0t_64_sync+0x190/0x194
Code: ???????? ???????? d2800001 d2800000 (b900003f) 
---[ end trace 0000000000000000 ]---
```

### FAULT IDENTIFICATION
```
pc : faulty_write+0x8/0x10 [faulty]
```
> Fault occurs at offset 0x8 of faulty_write function

```
Code: ???????? ???????? d2800001 d2800000 (b900003f)
```
> (b900003f) is fault assembly code


```
$ cd buildroot/output/build/lld-<hash_code>/misc-modules
$ ../../../host/bin/aarch64-linux-objdump -S faulty.o
Disassembly of section .text:

0000000000000000 <faulty_write>:
   0:	d2800001 	mov	x1, #0x0                   	// #0
   4:	d2800000 	mov	x0, #0x0                   	// #0
   8:	b900003f 	str	wzr, [x1]
   c:	d65f03c0 	ret
```
> offset 0x8 is (b900003f) str	wzr, [x1]

```
misc-modules/faulty.c:
ssize_t faulty_write (struct file *filp, const char __user *buf, size_t count,
		loff_t *pos)
{
	/* make a simple fault by dereferencing a NULL pointer */
	*(int *)0 = 0;
	return 0;
}
```
> *(int *)0 = 0; makes oops

