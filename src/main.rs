#![feature(lang_items, start)]
#![no_std]
#![cfg_attr(not(test), no_main)]

use alloc::string::String;
use core::{
    ffi::{c_int, c_void},
    fmt::Write,
    panic::PanicInfo,
};
use linux_raw_sys::{
    ctypes::{c_long, c_uint},
    general::{
        __NR_rt_sigaction, __kernel_sighandler_t, __sigrestore_t, siginfo_t, sigset_t, SA_RESTORER,
        SA_SIGINFO, SIGSEGV,
    },
};
use rustix::{
    fd::AsRawFd,
    fs::{cwd, Mode, OFlags},
    io::stdout,
};
use rustix_uring::{opcode, types, IoUring};
use sjlj::{siglongjmp, sigsetjmp, SigJumpBuf};

extern crate alloc;
extern crate origin;

mustang::can_run_this!();

#[cfg(not(test))]
#[panic_handler]
fn panic(_panic: &PanicInfo<'_>) -> ! {
    loop {}
}

#[cfg(not(test))]
#[lang = "eh_personality"]
extern "C" fn eh_personality() {}

// Cannot use origin's `env_logger` because it requires std. Thus just copied the function but
// instead initializes up our own logger
#[link_section = ".init_array.00000"]
#[cfg(feature = "log")]
#[used]
static INIT_ARRAY: unsafe extern "C" fn() = {
    unsafe extern "C" fn function() {
        // TODO: initialize our own custom logger

        log::trace!(target: "origin::program", "Program started");

        log::trace!(target: "origin::threads", "Main Thread[{:?}] initialized", origin::current_thread_id());
    }
    function
};

#[cfg_attr(not(test), no_mangle)]
extern "C" fn main(_argc: c_int, _argv: *mut *mut u8, _envp: *mut *mut u8) -> c_int {
    register_signal_handler();
    let threads = 4;
    let addr = (&threads as *const _ as usize) + 0xfffff;
    let mut b = String::new();
    let fd = unsafe { stdout() };
    let ret = unsafe { sigsetjmp(&mut JMP_BUF, true) };
    b.clear();
    if ret == 0 {
        write!(&mut b, "Accessing: {}\n", addr).unwrap();
        rustix::io::write(fd, b.as_bytes()).unwrap();
        let x = unsafe { *(addr as *const usize) };
        unreachable!("Should segfault {}", x);
    }
    write!(&mut b, "Return Jumped: {}\n", ret).unwrap();
    rustix::io::write(fd, b.as_bytes()).unwrap();
    let mut ring = IoUring::new(8).unwrap();

    let fd = rustix::fs::openat(cwd(), "README.md", OFlags::RDONLY, Mode::empty()).unwrap();

    let mut buf = alloc::vec![0; 1024];

    let read_e = opcode::Read::new(types::Fd(fd.as_raw_fd()), buf.as_mut_ptr(), buf.len() as _)
        .build()
        .user_data(types::IoringUserData { u64_: 0x42 });

    // Note that the developer needs to ensure
    // that the entry pushed into submission queue is valid (e.g. fd, buffer).
    unsafe {
        ring.submission()
            .push(&read_e)
            .expect("submission queue is full");
    }

    ring.submit_and_wait(1).unwrap();

    let cqe = ring.completion().next().expect("completion queue is empty");
    rustix::io::write(unsafe { stdout() }, &buf).unwrap();

    assert_eq!(cqe.user_data().u64_(), 0x42);
    assert!(cqe.result() >= 0, "read error: {}", cqe.result());

    0
}

static mut JMP_BUF: SigJumpBuf = SigJumpBuf::new();

#[derive(Debug)]
pub enum PageStatus {
    Unlocked,
    LockedShared(u8),
    Locked,
    Marked,
    Evicted,
}

pub union SigHandler {
    pub sa_handler: __kernel_sighandler_t,
    pub sa_sigaction:
        Option<unsafe extern "C" fn(sig: c_uint, info: *mut siginfo_t, ucontext: *mut c_void)>,
}

pub struct Sigaction {
    pub h: SigHandler,
    pub sa_flags: c_long,
    pub sa_restorer: __sigrestore_t,
    pub sa_mask: sigset_t,
}

// unsafe fn abort() -> () {
//     let tid = mustang::origin::current_thread_id();
//     assert!(kill_process_group(tid, rustix::process::Signal::Abort).is_ok());
//     unreachable_unchecked();
// }

extern "C" fn sigsegv_handler(_sig: c_uint, info: *mut siginfo_t, _ucontext: *mut c_void) {
    let page = unsafe {
        (*info)
            .__bindgen_anon_1
            .__bindgen_anon_1
            ._sifields
            ._sigfault
            ._addr
    } as usize;

    let fd = unsafe { stdout() };
    let mut b = String::new();
    write!(&mut b, "Fault Address: {}\n", page).unwrap();
    rustix::io::write(fd, b.as_bytes()).unwrap();
    drop(b);
    unsafe { siglongjmp(&JMP_BUF, 5) }
}

fn register_signal_handler() {
    unsafe {
        let mut x: Sigaction = core::mem::zeroed();
        x.h.sa_sigaction = Some(sigsegv_handler);
        x.sa_mask = 0;
        x.sa_flags = (SA_RESTORER | SA_SIGINFO).into();
        x.sa_restorer = None;
        let r = sc::syscall4(
            __NR_rt_sigaction as usize,
            SIGSEGV as usize,
            &x as *const _ as usize,
            0,
            core::mem::size_of::<sigset_t>(),
        );
        debug_assert!(r == 0);
    }
}

#[test]
fn fail() {
    assert!(3 == 3);
}
//
// impl Into<u8> for PageStatus {
//     fn into(self) -> u8 {
//         match self {
//             Self::Unlocked => 0,
//             Self::Locked => 253,
//             Self::Marked => 254,
//             Self::Evicted => 255,
//             Self::LockedShared(v) => v,
//         }
//     }
// }
//
// impl From<u8> for PageStatus {
//     fn from(v: u8) -> Self {
//         match v {
//             0 => Self::Unlocked,
//             253 => Self::Locked,
//             254 => Self::Marked,
//             255 => Self::Evicted,
//             v => Self::LockedShared(v),
//         }
//     }
// }
//
// #[derive(Clone, Copy)]
// pub struct PageState {
//     data: [u8; 8],
// }
//
// impl PageState {
//     pub fn new() -> Self {
//         Self { data: [0; 8] }
//     }
//
//     pub fn version(&self) -> u64 {
//         u64::from_le_bytes([
//             self.data[0],
//             self.data[1],
//             self.data[2],
//             self.data[3],
//             self.data[4],
//             self.data[5],
//             self.data[6],
//             0,
//         ])
//     }
//
//     pub fn set_version(&mut self, new_val: u64) {
//         assert!(new_val < (0x01_u64 << 56));
//         let le_bytes = new_val.to_le_bytes();
//         self.data[..7].copy_from_slice(&le_bytes[..7])
//     }
//
//     pub fn status(&self) -> PageStatus {
//         u8::from_le_bytes([self.data[8]]).into()
//     }
//
//     pub fn set_status(&mut self, new_val: PageStatus) {
//         let v: u8 = new_val.into();
//         self.data[7] = v.to_le_bytes()[0]
//     }
// }
//
// impl From<u64> for PageState {
//     fn from(v: u64) -> Self {
//         Self {
//             data: v.to_le_bytes(),
//         }
//     }
// }
//
// impl Into<u64> for PageState {
//     fn into(self) -> u64 {
//         u64::from_le_bytes(self.data)
//     }
// }
//
// struct PageStates<const S: usize>(Box<[AtomicU64; S]>);
//
// impl<const S: usize> PageStates<S> {
//     fn new() -> PageStates<S> {
//         let init = 0;
//
//         let entries = {
//             let mut entries: Box<[MaybeUninit<AtomicU64>; S]> =
//                 Box::new(unsafe { MaybeUninit::uninit().assume_init() });
//
//             for entry in entries.iter_mut() {
//                 entry.write(AtomicU64::new(init));
//             }
//
//             unsafe { core::mem::transmute::<_, Box<[AtomicU64; S]>>(entries) }
//         };
//
//         PageStates(entries)
//     }
// }

// struct BufferManager<const S: usize> {
//     entries: PageStates<S>,
// }

// impl<const S: usize> BufferManager<S> {
// pub fn new() -> BufferManager<S> {
//     backing_fd = fs::openat(fs::cwd(), "/tmp/bm", OFlags::, O_DIRECT);
//     BufferManager {
//         entries: PageStates::new(),
//     }
// }

// fn fix_multiple<const P: usize>(&self, mut interface: InterfaceWrapper<InterfaceIov>) {
//     // Deadlock prone
//     let mut miss_length = 0;
//     let mut overwrite_prev_iov = false;

//     for i in 0..interface.len() {
//         let pid_start = interface[i].page();
//         let len = interface[i].len();

//         if overwrite_prev_iov {
//             interface[miss_length].set_page(pid_start);
//             interface[miss_length].set_len(len)
//         }

//         for pid in pid_start..pid_start + len {
//             loop {
//                 let state = self.entries.get(pid as usize).unwrap();

//                 let curr_state = state.load(Ordering::Relaxed);
//                 let mut legible_state = PageState::from(curr_state);

//                 match legible_state.status() {
//                     PageStatus::Evicted => {
//                         legible_state.set_status(PageStatus::Locked);
//                         if state
//                             .compare_exchange(
//                                 curr_state,
//                                 legible_state.into(),
//                                 Ordering::Relaxed,
//                                 Ordering::Relaxed,
//                             )
//                             .is_ok()
//                         {
//                             miss_length += 1;
//                             break;
//                         };
//                     }
//                     PageStatus::Marked | PageStatus::Unlocked => {
//                         legible_state.set_status(PageStatus::Locked);
//                         if state
//                             .compare_exchange(
//                                 curr_state,
//                                 legible_state.into(),
//                                 Ordering::Relaxed,
//                                 Ordering::Relaxed,
//                             )
//                             .is_ok()
//                         {
//                             overwrite_prev_iov = true;
//                             break;
//                         };
//                     }
//                     _ => continue,
//                 }
//             }
//         }
//     }
// }
// }

// fn test() {
// let exmap_fd = OwnedExmapFd::<4096>::open().unwrap();
// let mut exmap = exmap_fd
//     .create(
//         threads as usize * 4 * 1024 * 1024,
//         threads,
//         threads as usize * 512,
//         None,
//     )
//     .unwrap();

// let mut interface = unsafe { exmap_fd.mmap_interface(0).unwrap() };
// for i in 0..8 {
//     interface.push(i, 1).unwrap();
// }

// interface.push(10, 2).unwrap();
// interface.push(2090, 10).unwrap();
// interface.push(4095, 1).unwrap();

// for v in interface.iter() {}

// let (interface, res) = interface.alloc();

// for v in interface.iter() {}

// let size = exmap.size();
// let x = exmap.as_mut();
// x[0] = 3;
// x[size - 1] = 10;

// let mut interface = interface.into_iov();
// for i in 0..5 {
//     interface.push(i, 1).unwrap();
// }
// interface.push(1037, 1805).unwrap();
// for v in interface.iter() {}
// let (interface, res) = interface.free();
// for v in interface.iter() {}

// exmap.unmap();
// interface.unmap().unwrap();
// drop(exmap_fd);
// }
