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

// --- USB HID Key Codes (Page 0x07) ---
// Internal key codes use USB HID Keyboard Usage IDs.
// Platform layers map native key codes to these values.

#define AGILIS_KEY_A              4
#define AGILIS_KEY_Z             29
#define AGILIS_KEY_1             30
#define AGILIS_KEY_0             39
#define AGILIS_KEY_ENTER         40
#define AGILIS_KEY_ESCAPE        41
#define AGILIS_KEY_BACKSPACE     42
#define AGILIS_KEY_TAB           43
#define AGILIS_KEY_SPACE         44
#define AGILIS_KEY_MINUS         45
#define AGILIS_KEY_EQUAL         46
#define AGILIS_KEY_LEFT_BRACKET  47
#define AGILIS_KEY_RIGHT_BRACKET 48
#define AGILIS_KEY_BACKSLASH     49
#define AGILIS_KEY_SEMICOLON     51
#define AGILIS_KEY_APOSTROPHE    52
#define AGILIS_KEY_GRAVE         53
#define AGILIS_KEY_COMMA         54
#define AGILIS_KEY_PERIOD        55
#define AGILIS_KEY_SLASH         56
#define AGILIS_KEY_CAPS_LOCK     57
#define AGILIS_KEY_F1            58
#define AGILIS_KEY_F12           69
#define AGILIS_KEY_PRINT_SCREEN  70
#define AGILIS_KEY_SCROLL_LOCK   71
#define AGILIS_KEY_PAUSE         72
#define AGILIS_KEY_INSERT        73
#define AGILIS_KEY_HOME          74
#define AGILIS_KEY_PAGE_UP       75
#define AGILIS_KEY_DELETE        76
#define AGILIS_KEY_END           77
#define AGILIS_KEY_PAGE_DOWN     78
#define AGILIS_KEY_RIGHT         79
#define AGILIS_KEY_LEFT          80
#define AGILIS_KEY_DOWN          81
#define AGILIS_KEY_UP            82
#define AGILIS_KEY_NUM_LOCK      83
#define AGILIS_KEY_MENU         101
#define AGILIS_KEY_LEFT_CONTROL 224
#define AGILIS_KEY_LEFT_SHIFT   225
#define AGILIS_KEY_LEFT_ALT     226
#define AGILIS_KEY_LEFT_SUPER   227
#define AGILIS_KEY_RIGHT_CONTROL 228
#define AGILIS_KEY_RIGHT_SHIFT  229
#define AGILIS_KEY_RIGHT_ALT    230
#define AGILIS_KEY_RIGHT_SUPER  231

#define AGILIS_MAX_KEYS         256
#define AGILIS_MAX_MOUSE_BUTTONS 5
#define AGILIS_MAX_GAMEPADS      4

// --- Keyboard ---

bool     platform_is_key_down(PlatformWindow* w, int key);
bool     platform_key_pressed(PlatformWindow* w, int key);         // true if pressed this poll
uint32_t platform_char_pressed(PlatformWindow* w);  // Unicode codepoint, or 0

// --- Mouse ---

bool  platform_is_mouse_button_down(PlatformWindow* w, int button);  // 0=left, 1=right, 2=middle, 3=back, 4=forward
bool  platform_mouse_button_pressed(PlatformWindow* w, int button); // true if pressed this poll
float platform_mouse_x(PlatformWindow* w);
float platform_mouse_y(PlatformWindow* w);
float platform_mouse_dx(PlatformWindow* w);     // Delta since last poll
float platform_mouse_dy(PlatformWindow* w);     // Delta since last poll
float platform_mouse_scroll(PlatformWindow* w); // Scroll wheel delta

// Cursor visibility
void platform_show_cursor(PlatformWindow* w, bool visible);
bool platform_is_cursor_visible(PlatformWindow* w);

// Mouse capture (locks cursor to window center, hides cursor, reports raw deltas)
void platform_set_mouse_captured(PlatformWindow* w, bool captured);
bool platform_is_mouse_captured(PlatformWindow* w);

// --- Gamepad (up to 4) ---

bool        platform_is_gamepad_available(int index);
bool        platform_is_gamepad_button_down(int index, int button);
bool        platform_gamepad_button_pressed(int index, int button);  // true if pressed this poll
float       platform_gamepad_axis(int index, int axis);
const char* platform_gamepad_name(int index);

// Gamepad rumble/vibration (0.0–1.0 for each motor)
void platform_gamepad_set_vibration(int index, float leftMotor, float rightMotor);

// --- Touch Input (iOS) ---

#define AGILIS_MAX_TOUCHES      10
#define AGILIS_TOUCH_BEGAN      0
#define AGILIS_TOUCH_MOVED      1
#define AGILIS_TOUCH_ENDED      2
#define AGILIS_TOUCH_CANCELLED  3

typedef struct PlatformTouch {
    int32_t id;         // Unique touch identifier
    float x, y;         // Position in view coordinates (origin top-left)
    int32_t phase;      // AGILIS_TOUCH_BEGAN/MOVED/ENDED/CANCELLED
} PlatformTouch;

int  platform_touch_count(PlatformWindow* w);
PlatformTouch platform_touch_at(PlatformWindow* w, int index);

// --- Frame Timing ---

void platform_set_target_fps(PlatformWindow* w, int fps);
void platform_set_vsync(PlatformWindow* w, bool enabled);

#ifdef __cplusplus
}
#endif

#endif // PLATFORM_H
