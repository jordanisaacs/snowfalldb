#![feature(lang_items, start)]
#![no_std]
#![no_main]

mustang::can_run_this!();

use core::{ffi::c_int, panic::PanicInfo};

#[panic_handler]
fn panic(_panic: &PanicInfo<'_>) -> ! {
    loop {}
}

#[lang = "eh_personality"]
extern "C" fn eh_personality() {}

#[no_mangle]
extern "C" fn main(_argc: c_int, _argv: *mut *mut u8, _envp: *mut *mut u8) -> c_int {
    0
}
