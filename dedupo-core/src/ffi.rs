//! C ABI exports for FFI bridging with Swift.
//!
//! All public functions in this module use `extern "C"` and `#[no_mangle]`
//! to be callable from the Swift side via the generated C header.

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_void};
use std::sync::Arc;

use crate::types::ScanProgress;
use crate::Engine;

// ===== Lifecycle Management =====

/// Create a new engine instance.
///
/// # Safety
/// `db_path` must be a valid null-terminated C string.
/// The caller must free the returned pointer with `dedupo_engine_free`.
#[no_mangle]
pub unsafe extern "C" fn dedupo_engine_create(db_path: *const c_char) -> *mut Engine {
    if db_path.is_null() {
        return std::ptr::null_mut();
    }

    let path = match unsafe { CStr::from_ptr(db_path) }.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    match Engine::new(path) {
        Ok(engine) => Box::into_raw(Box::new(engine)),
        Err(e) => {
            log::error!("Failed to create engine: {}", e);
            std::ptr::null_mut()
        }
    }
}

/// Free an engine instance.
///
/// # Safety
/// `engine` must be a valid pointer returned by `dedupo_engine_create`,
/// or null (in which case this is a no-op).
#[no_mangle]
pub unsafe extern "C" fn dedupo_engine_free(engine: *mut Engine) {
    if !engine.is_null() {
        drop(unsafe { Box::from_raw(engine) });
    }
}

// ===== Scan Control =====

/// Add a scan target path.
///
/// Returns 0 on success, -1 on failure.
///
/// # Safety
/// Both `engine` and `path` must be valid pointers.
#[no_mangle]
pub unsafe extern "C" fn dedupo_add_scan_path(
    engine: *mut Engine,
    path: *const c_char,
) -> c_int {
    if engine.is_null() || path.is_null() {
        return -1;
    }

    let engine = unsafe { &mut *engine };
    let path_str = match unsafe { CStr::from_ptr(path) }.to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };

    engine.add_scan_path(path_str);
    0
}

/// Clear all scan paths.
///
/// Call this before adding new paths for a fresh scan.
///
/// # Safety
/// `engine` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn dedupo_clear_scan_paths(engine: *mut Engine) {
    if !engine.is_null() {
        let engine = unsafe { &mut *engine };
        engine.clear_scan_paths();
    }
}

/// Progress callback type.
///
/// Parameters: scanned_count, total_estimated, phase (as i32), user context
pub type ProgressCallback = extern "C" fn(u64, u64, i32, *mut c_void);

/// Start an asynchronous scan.
///
/// The progress callback is invoked periodically with scan updates.
/// Returns 0 on success, -1 on failure, 1 if cancelled.
///
/// # Safety
/// `engine` must be a valid pointer. `context` is passed through to the callback.
#[no_mangle]
pub unsafe extern "C" fn dedupo_scan_start(
    engine: *mut Engine,
    progress_cb: ProgressCallback,
    context: *mut c_void,
) -> c_int {
    if engine.is_null() {
        return -1;
    }

    let engine = unsafe { &*engine };

    // Wrap context in an Arc for safe cross-thread sharing
    let context = Arc::new(SendPtr(context));

    let result = engine.scan(move |progress: ScanProgress| {
        let ctx = Arc::clone(&context);
        progress_cb(
            progress.scanned_count,
            progress.total_estimated,
            progress.phase as i32,
            ctx.0,
        );
    });

    match result {
        Ok(()) => 0,
        Err(crate::types::DeDupoError::Cancelled) => 1,
        Err(e) => {
            log::error!("Scan failed: {}", e);
            -1
        }
    }
}

/// Cancel an ongoing scan.
///
/// # Safety
/// `engine` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn dedupo_scan_cancel(engine: *mut Engine) {
    if !engine.is_null() {
        let engine = unsafe { &*engine };
        engine.cancel();
    }
}

// ===== Results =====

/// Get the number of duplicate groups found.
///
/// # Safety
/// `engine` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn dedupo_get_group_count(engine: *mut Engine) -> u64 {
    if engine.is_null() {
        return 0;
    }
    let engine = unsafe { &*engine };
    engine.group_count()
}

/// Get a duplicate group by index as a JSON string.
///
/// Returns null if the index is out of range.
/// The caller must free the returned string with `dedupo_free_string`.
///
/// # Safety
/// `engine` must be a valid pointer.
#[no_mangle]
pub unsafe extern "C" fn dedupo_get_group(
    engine: *mut Engine,
    index: u64,
) -> *mut c_char {
    if engine.is_null() {
        return std::ptr::null_mut();
    }

    let engine = unsafe { &*engine };
    match engine.get_group_json(index) {
        Some(json) => match CString::new(json) {
            Ok(cs) => cs.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        None => std::ptr::null_mut(),
    }
}

/// Free a string allocated by the Rust engine.
///
/// # Safety
/// `s` must be a pointer returned by a `dedupo_get_*` function, or null.
#[no_mangle]
pub unsafe extern "C" fn dedupo_free_string(s: *mut c_char) {
    if !s.is_null() {
        drop(unsafe { CString::from_raw(s) });
    }
}

// ===== File Operations =====

/// Move a file to the system trash.
///
/// Returns 0 on success, -1 on failure.
///
/// # Safety
/// `path` must be a valid null-terminated C string.
#[no_mangle]
pub unsafe extern "C" fn dedupo_trash_file(path: *const c_char) -> c_int {
    if path.is_null() {
        return -1;
    }

    let path_str = match unsafe { CStr::from_ptr(path) }.to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };

    // On macOS, moving to trash is handled by the Swift side (NSWorkspace).
    // This is a placeholder for cross-platform support.
    // For now, we simply verify the file exists.
    if std::path::Path::new(path_str).exists() {
        log::info!("Trash request for: {}", path_str);
        0
    } else {
        log::warn!("File not found for trash: {}", path_str);
        -1
    }
}

/// Wrapper to make a raw pointer Send + Sync for use across threads.
struct SendPtr(*mut c_void);
unsafe impl Send for SendPtr {}
unsafe impl Sync for SendPtr {}
