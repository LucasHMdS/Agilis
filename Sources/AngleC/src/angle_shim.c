// EGL wrapper functions that handle platform-specific native type casts.
// Swift cannot easily cast void* to platform-specific EGL native types
// (HDC on Windows, int on macOS, khronos_uintptr_t on Linux), so these
// C functions bridge the gap.

#include "angle.h"
#include <stddef.h>

#if defined(__unix__) && !defined(__APPLE__)
#include <stdint.h>
#endif

EGLDisplay angle_get_display(void* native_display) {
#if defined(__APPLE__)
    // macOS: EGLNativeDisplayType is int; ANGLE uses EGL_DEFAULT_DISPLAY
    (void)native_display;
    return eglGetDisplay(EGL_DEFAULT_DISPLAY);
#else
    // Windows: void* -> HDC (pointer cast)
    // Linux:   void* -> void* (no-op)
    return eglGetDisplay((EGLNativeDisplayType)native_display);
#endif
}

EGLSurface angle_create_window_surface(EGLDisplay display, EGLConfig config,
                                        void* native_window,
                                        const EGLint* attribs) {
#if defined(__unix__) && !defined(__APPLE__)
    // Linux: EGLNativeWindowType is khronos_uintptr_t (integer type)
    EGLNativeWindowType win = (EGLNativeWindowType)(uintptr_t)native_window;
#else
    // Windows: void* -> HWND (pointer cast)
    // macOS:   void* -> void* (no-op)
    EGLNativeWindowType win = (EGLNativeWindowType)native_window;
#endif
    return eglCreateWindowSurface(display, config, win, attribs);
}
