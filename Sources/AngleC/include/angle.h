// Umbrella header for ANGLE (EGL + OpenGL ES 3.0)
#ifndef ANGLE_H
#define ANGLE_H

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl3.h>

#ifdef __cplusplus
extern "C" {
#endif

// ---------------------------------------------------------------------------
// EGL wrapper functions
//
// These handle platform-specific native type casts so Swift can pass void*
// from PlatformC without worrying about EGLNativeDisplayType / WindowType.
// ---------------------------------------------------------------------------

/// Calls eglGetDisplay with proper platform-specific type casting.
/// Pass the result of platform_native_display().
EGLDisplay angle_get_display(void* native_display);

/// Calls eglCreateWindowSurface with proper platform-specific type casting.
/// Pass the result of platform_native_window().
EGLSurface angle_create_window_surface(EGLDisplay display, EGLConfig config,
                                        void* native_window,
                                        const EGLint* attribs);

/// Creates an EGL pbuffer surface for headless (off-screen) rendering.
/// Used for snapshot testing without a platform window.
EGLSurface angle_create_pbuffer_surface(EGLDisplay display, EGLConfig config,
                                         EGLint width, EGLint height);

#ifdef __cplusplus
}
#endif

#endif // ANGLE_H
