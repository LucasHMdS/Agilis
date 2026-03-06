#ifndef PLATFORM_H
#define PLATFORM_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// --- Window Configuration ---

typedef struct PlatformWindowConfig {
    const char* title;
    int width;
    int height;
    int target_fps;     // 0 = uncapped
    bool resizable;
    bool vsync;
} PlatformWindowConfig;

// Opaque window handle
typedef struct PlatformWindow PlatformWindow;

// --- Window Lifecycle ---

PlatformWindow* platform_create_window(const PlatformWindowConfig* config);
void platform_destroy_window(PlatformWindow* w);
bool platform_should_close(PlatformWindow* w);
void platform_poll_events(PlatformWindow* w);
int  platform_window_width(PlatformWindow* w);
int  platform_window_height(PlatformWindow* w);
bool platform_window_resized(PlatformWindow* w);

// --- EGL Surface Hooks ---

// Returns the native display handle (EGLNativeDisplayType).
// Win32: GetDC(hwnd), macOS: EGL_DEFAULT_DISPLAY, Linux: X11 Display*
void* platform_native_display(PlatformWindow* w);

// Returns the native window handle (EGLNativeWindowType).
// Win32: HWND, macOS: NSView*/CALayer*, Linux: X11 Window
void* platform_native_window(PlatformWindow* w);

// --- Keyboard ---
// Key codes use GLFW key code values (see Key enum in Agilis).
// The platform layer maps native key codes to GLFW codes internally.

bool     platform_is_key_down(PlatformWindow* w, int key);
bool     platform_key_pressed(PlatformWindow* w, int key);         // true if pressed this poll
uint32_t platform_char_pressed(PlatformWindow* w);  // Unicode codepoint, or 0

// --- Mouse ---

bool  platform_is_mouse_button_down(PlatformWindow* w, int button);  // 0=left, 1=right, 2=middle
bool  platform_mouse_button_pressed(PlatformWindow* w, int button); // true if pressed this poll
float platform_mouse_x(PlatformWindow* w);
float platform_mouse_y(PlatformWindow* w);
float platform_mouse_dx(PlatformWindow* w);     // Delta since last poll
float platform_mouse_dy(PlatformWindow* w);     // Delta since last poll
float platform_mouse_scroll(PlatformWindow* w); // Scroll wheel delta

// --- Gamepad (up to 4) ---

bool        platform_is_gamepad_available(int index);
bool        platform_is_gamepad_button_down(int index, int button);
float       platform_gamepad_axis(int index, int axis);
const char* platform_gamepad_name(int index);

// --- Frame Timing ---

void platform_set_target_fps(PlatformWindow* w, int fps);
void platform_set_vsync(PlatformWindow* w, bool enabled);

#ifdef __cplusplus
}
#endif

#endif // PLATFORM_H
