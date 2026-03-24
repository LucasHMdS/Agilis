#ifdef __linux__

#include "platform.h"
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <linux/joystick.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/ioctl.h>

// ---- Gamepad Constants ----
#define MAX_GAMEPAD_BUTTONS 18
#define MAX_GAMEPAD_AXES 6

// ---- Global Gamepad State (joystick API) ----

static struct {
    int fd;                             // file descriptor, -1 if not connected
    bool buttons[MAX_GAMEPAD_BUTTONS];  // mapped Agilis buttons
    bool buttons_pressed[MAX_GAMEPAD_BUTTONS]; // sticky per poll
    float axes[MAX_GAMEPAD_AXES];       // mapped Agilis axes
    char name[128];
} g_gamepads[AGILIS_MAX_GAMEPADS];
static bool g_gamepads_initialized = false;
static int g_gamepad_rescan_counter = 0;

// Map Linux joystick button to Agilis GamepadButton raw value
// Layout follows Xbox-style controllers (most common on Linux)
static int linux_button_to_agilis(int btn) {
    switch (btn) {
        case 0: return 7;   // BTN_A → faceDown
        case 1: return 6;   // BTN_B → faceRight
        case 2: return 8;   // BTN_X → faceLeft
        case 3: return 5;   // BTN_Y → faceUp
        case 4: return 9;   // LB → leftBumper
        case 5: return 11;  // RB → rightBumper
        case 6: return 13;  // Back → select
        case 7: return 15;  // Start → start
        case 8: return 14;  // Guide → home
        case 9: return 16;  // L3 → leftStick
        case 10: return 17; // R3 → rightStick
        default: return -1;
    }
}

static void gamepad_init(void) {
    if (g_gamepads_initialized) return;
    g_gamepads_initialized = true;
    for (int i = 0; i < AGILIS_MAX_GAMEPADS; i++) {
        g_gamepads[i].fd = -1;
        g_gamepads[i].name[0] = '\0';
    }
}

static void gamepad_try_open(int index) {
    if (g_gamepads[index].fd >= 0) return; // already open
    char path[32];
    snprintf(path, sizeof(path), "/dev/input/js%d", index);
    int fd = open(path, O_RDONLY | O_NONBLOCK);
    if (fd < 0) return;
    g_gamepads[index].fd = fd;
    // Read controller name
    if (ioctl(fd, JSIOCGNAME(128), g_gamepads[index].name) < 0) {
        strncpy(g_gamepads[index].name, "Controller", 127);
    }
    g_gamepads[index].name[127] = '\0';
    memset(g_gamepads[index].buttons, 0, sizeof(g_gamepads[index].buttons));
    memset(g_gamepads[index].axes, 0, sizeof(g_gamepads[index].axes));
}

static void gamepad_poll(void) {
    gamepad_init();

    // Periodic re-scan for hot-plug (every ~60 polls ≈ 1 second at 60fps)
    g_gamepad_rescan_counter++;
    if (g_gamepad_rescan_counter >= 60) {
        g_gamepad_rescan_counter = 0;
        for (int i = 0; i < AGILIS_MAX_GAMEPADS; i++) {
            gamepad_try_open(i);
        }
    }

    for (int i = 0; i < AGILIS_MAX_GAMEPADS; i++) {
        memset(g_gamepads[i].buttons_pressed, 0, sizeof(g_gamepads[i].buttons_pressed));
        if (g_gamepads[i].fd < 0) continue;

        struct js_event ev;
        while (read(g_gamepads[i].fd, &ev, sizeof(ev)) == sizeof(ev)) {
            ev.type &= ~JS_EVENT_INIT; // strip init flag

            if (ev.type == JS_EVENT_BUTTON) {
                int mapped = linux_button_to_agilis(ev.number);
                if (mapped >= 0 && mapped < MAX_GAMEPAD_BUTTONS) {
                    bool prev = g_gamepads[i].buttons[mapped];
                    g_gamepads[i].buttons[mapped] = ev.value ? true : false;
                    if (ev.value && !prev) {
                        g_gamepads[i].buttons_pressed[mapped] = true;
                    }
                }
            } else if (ev.type == JS_EVENT_AXIS) {
                float val = (float)ev.value / 32767.0f;
                switch (ev.number) {
                    case 0: g_gamepads[i].axes[0] = val; break;  // LX → leftX
                    case 1: g_gamepads[i].axes[1] = val; break;  // LY → leftY
                    case 2: {
                        // LT — may be -32767..32767, normalize to 0..1
                        float lt = ((float)ev.value + 32767.0f) / 65534.0f;
                        g_gamepads[i].axes[4] = lt;
                        // Also set as digital button
                        bool lt_cur = lt > 0.5f;
                        bool lt_prev = g_gamepads[i].buttons[10];
                        g_gamepads[i].buttons[10] = lt_cur;
                        if (lt_cur && !lt_prev) g_gamepads[i].buttons_pressed[10] = true;
                        break;
                    }
                    case 3: g_gamepads[i].axes[2] = val; break;  // RX → rightX
                    case 4: g_gamepads[i].axes[3] = val; break;  // RY → rightY
                    case 5: {
                        // RT — may be -32767..32767, normalize to 0..1
                        float rt = ((float)ev.value + 32767.0f) / 65534.0f;
                        g_gamepads[i].axes[5] = rt;
                        bool rt_cur = rt > 0.5f;
                        bool rt_prev = g_gamepads[i].buttons[12];
                        g_gamepads[i].buttons[12] = rt_cur;
                        if (rt_cur && !rt_prev) g_gamepads[i].buttons_pressed[12] = true;
                        break;
                    }
                    case 6: {
                        // DpadX: -1 = left, 0 = center, 1 = right
                        g_gamepads[i].buttons[4] = (ev.value < 0); // dpadLeft
                        g_gamepads[i].buttons[2] = (ev.value > 0); // dpadRight
                        break;
                    }
                    case 7: {
                        // DpadY: -1 = up, 0 = center, 1 = down
                        g_gamepads[i].buttons[1] = (ev.value < 0); // dpadUp
                        g_gamepads[i].buttons[3] = (ev.value > 0); // dpadDown
                        break;
                    }
                }
            }
        }

        // Check for disconnect (read returns -1 with errno != EAGAIN)
        if (errno != EAGAIN && errno != 0) {
            close(g_gamepads[i].fd);
            g_gamepads[i].fd = -1;
            g_gamepads[i].name[0] = '\0';
            memset(g_gamepads[i].buttons, 0, sizeof(g_gamepads[i].buttons));
            memset(g_gamepads[i].axes, 0, sizeof(g_gamepads[i].axes));
        }
    }
}

// ---- X11 KeySym -> USB HID Key Mapping ----
// Key codes defined in platform.h (AGILIS_KEY_*, AGILIS_MAX_*)

static int xkeysym_to_agilis(KeySym ks) {
    // Letters (XK_a=0x61..XK_z=0x7A → USB HID 4..29)
    if (ks >= XK_a && ks <= XK_z) return AGILIS_KEY_A + (int)(ks - XK_a);
    if (ks >= XK_A && ks <= XK_Z) return AGILIS_KEY_A + (int)(ks - XK_A);

    // Digits: XK_1..XK_9 → USB HID 30..38, XK_0 → USB HID 39
    if (ks >= XK_1 && ks <= XK_9) return AGILIS_KEY_1 + (int)(ks - XK_1);
    if (ks == XK_0) return AGILIS_KEY_0;

    // Function keys (XK_F1..XK_F12 → USB HID 58..69)
    if (ks >= XK_F1 && ks <= XK_F12) return AGILIS_KEY_F1 + (int)(ks - XK_F1);

    switch (ks) {
        // Special keys
        case XK_Return:      return AGILIS_KEY_ENTER;
        case XK_Escape:      return AGILIS_KEY_ESCAPE;
        case XK_BackSpace:   return AGILIS_KEY_BACKSPACE;
        case XK_Tab:         return AGILIS_KEY_TAB;
        case XK_space:       return AGILIS_KEY_SPACE;

        // Punctuation
        case XK_minus:       return AGILIS_KEY_MINUS;
        case XK_equal:       return AGILIS_KEY_EQUAL;
        case XK_bracketleft: return AGILIS_KEY_LEFT_BRACKET;
        case XK_bracketright:return AGILIS_KEY_RIGHT_BRACKET;
        case XK_backslash:   return AGILIS_KEY_BACKSLASH;
        case XK_semicolon:   return AGILIS_KEY_SEMICOLON;
        case XK_apostrophe:  return AGILIS_KEY_APOSTROPHE;
        case XK_grave:       return AGILIS_KEY_GRAVE;
        case XK_comma:       return AGILIS_KEY_COMMA;
        case XK_period:      return AGILIS_KEY_PERIOD;
        case XK_slash:       return AGILIS_KEY_SLASH;

        // Lock keys
        case XK_Caps_Lock:   return AGILIS_KEY_CAPS_LOCK;
        case XK_Scroll_Lock: return AGILIS_KEY_SCROLL_LOCK;
        case XK_Num_Lock:    return AGILIS_KEY_NUM_LOCK;

        // System keys
        case XK_Print:       return AGILIS_KEY_PRINT_SCREEN;
        case XK_Pause:       return AGILIS_KEY_PAUSE;

        // Navigation
        case XK_Insert:      return AGILIS_KEY_INSERT;
        case XK_Home:        return AGILIS_KEY_HOME;
        case XK_Prior:       return AGILIS_KEY_PAGE_UP;     // XK_Prior = Page Up
        case XK_Delete:      return AGILIS_KEY_DELETE;
        case XK_End:         return AGILIS_KEY_END;
        case XK_Next:        return AGILIS_KEY_PAGE_DOWN;   // XK_Next = Page Down
        case XK_Right:       return AGILIS_KEY_RIGHT;
        case XK_Left:        return AGILIS_KEY_LEFT;
        case XK_Down:        return AGILIS_KEY_DOWN;
        case XK_Up:          return AGILIS_KEY_UP;

        // Application key
        case XK_Menu:        return AGILIS_KEY_MENU;

        // Modifiers
        case XK_Control_L:   return AGILIS_KEY_LEFT_CONTROL;
        case XK_Shift_L:     return AGILIS_KEY_LEFT_SHIFT;
        case XK_Alt_L:       return AGILIS_KEY_LEFT_ALT;
        case XK_Super_L:     return AGILIS_KEY_LEFT_SUPER;
        case XK_Control_R:   return AGILIS_KEY_RIGHT_CONTROL;
        case XK_Shift_R:     return AGILIS_KEY_RIGHT_SHIFT;
        case XK_Alt_R:       return AGILIS_KEY_RIGHT_ALT;
        case XK_Super_R:     return AGILIS_KEY_RIGHT_SUPER;

        default:             return -1;
    }
}

// ---- Platform Window ----

struct PlatformWindow {
    Display* display;
    Window x_window;
    Atom wm_delete;
    bool should_close;
    bool resized;
    int width;
    int height;

    bool keys[AGILIS_MAX_KEYS];
    bool keys_pressed[AGILIS_MAX_KEYS];           // sticky: set on DOWN, cleared per poll
    uint32_t char_pressed;

    bool mouse_buttons[AGILIS_MAX_MOUSE_BUTTONS];
    bool mouse_buttons_pressed[AGILIS_MAX_MOUSE_BUTTONS]; // sticky: set on DOWN, cleared per poll
    float mouse_x, mouse_y;
    float mouse_dx, mouse_dy;
    float mouse_scroll;
    float prev_mouse_x, prev_mouse_y;
    bool mouse_initialized;

    // Cursor state
    bool cursor_visible;
    bool mouse_captured;
    Cursor blank_cursor;   // cached invisible cursor for hide/capture

    int target_fps;
    bool vsync;
};

// ---- Window Lifecycle ----

PlatformWindow* platform_create_window(const PlatformWindowConfig* config) {
    PlatformWindow* w = (PlatformWindow*)calloc(1, sizeof(PlatformWindow));
    if (!w) return NULL;

    w->display = XOpenDisplay(NULL);
    if (!w->display) {
        free(w);
        return NULL;
    }

    int screen = DefaultScreen(w->display);
    Window root = RootWindow(w->display, screen);

    w->x_window = XCreateSimpleWindow(
        w->display, root,
        0, 0, config->width, config->height, 0,
        BlackPixel(w->display, screen),
        BlackPixel(w->display, screen)
    );

    // Set window title
    XStoreName(w->display, w->x_window, config->title);

    // Request close events
    w->wm_delete = XInternAtom(w->display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(w->display, w->x_window, &w->wm_delete, 1);

    // Select input events
    XSelectInput(w->display, w->x_window,
        KeyPressMask | KeyReleaseMask |
        ButtonPressMask | ButtonReleaseMask |
        PointerMotionMask | StructureNotifyMask);

    // Set size hints if not resizable
    if (!config->resizable) {
        XSizeHints hints;
        hints.flags = PMinSize | PMaxSize;
        hints.min_width = config->width;
        hints.min_height = config->height;
        hints.max_width = config->width;
        hints.max_height = config->height;
        XSetWMNormalHints(w->display, w->x_window, &hints);
    }

    w->width = config->width;
    w->height = config->height;
    w->target_fps = config->target_fps;
    w->vsync = config->vsync;
    w->cursor_visible = true;

    // Create blank cursor for hiding/capture
    {
        XColor dummy;
        memset(&dummy, 0, sizeof(dummy));
        Pixmap blank_pixmap = XCreatePixmap(w->display, w->x_window, 1, 1, 1);
        w->blank_cursor = XCreatePixmapCursor(w->display, blank_pixmap, blank_pixmap, &dummy, &dummy, 0, 0);
        XFreePixmap(w->display, blank_pixmap);
    }

    XMapWindow(w->display, w->x_window);
    XFlush(w->display);

    return w;
}

void platform_destroy_window(PlatformWindow* w) {
    if (!w) return;
    if (w->blank_cursor) XFreeCursor(w->display, w->blank_cursor);
    if (w->x_window) XDestroyWindow(w->display, w->x_window);
    if (w->display) XCloseDisplay(w->display);
    free(w);
}

bool platform_should_close(PlatformWindow* w) {
    return w ? w->should_close : true;
}

void platform_poll_events(PlatformWindow* w) {
    if (!w) return;

    // Compute mouse delta
    if (w->mouse_initialized) {
        w->mouse_dx = w->mouse_x - w->prev_mouse_x;
        w->mouse_dy = w->mouse_y - w->prev_mouse_y;
    } else {
        w->mouse_dx = 0;
        w->mouse_dy = 0;
        w->mouse_initialized = true;
    }
    w->prev_mouse_x = w->mouse_x;
    w->prev_mouse_y = w->mouse_y;

    w->mouse_scroll = 0;
    w->char_pressed = 0;
    w->resized = false;

    memset(w->keys_pressed, 0, sizeof(w->keys_pressed));
    memset(w->mouse_buttons_pressed, 0, sizeof(w->mouse_buttons_pressed));

    while (XPending(w->display)) {
        XEvent event;
        XNextEvent(w->display, &event);

        switch (event.type) {
            case KeyPress: {
                KeySym ks = XLookupKeysym(&event.xkey, 0);
                int key = xkeysym_to_agilis(ks);
                if (key >= 0 && key < AGILIS_MAX_KEYS) {
                    w->keys[key] = true;
                    w->keys_pressed[key] = true;
                }

                // Text input
                char buf[8];
                int len = XLookupString(&event.xkey, buf, sizeof(buf), NULL, NULL);
                if (len > 0 && (unsigned char)buf[0] >= 32)
                    w->char_pressed = (uint32_t)(unsigned char)buf[0];
                break;
            }
            case KeyRelease: {
                // Check for auto-repeat (next event is KeyPress with same time)
                if (XEventsQueued(w->display, QueuedAfterReading)) {
                    XEvent next;
                    XPeekEvent(w->display, &next);
                    if (next.type == KeyPress &&
                        next.xkey.time == event.xkey.time &&
                        next.xkey.keycode == event.xkey.keycode) {
                        // Auto-repeat, skip both
                        XNextEvent(w->display, &next);
                        break;
                    }
                }
                KeySym ks = XLookupKeysym(&event.xkey, 0);
                int key = xkeysym_to_agilis(ks);
                if (key >= 0 && key < AGILIS_MAX_KEYS)
                    w->keys[key] = false;
                break;
            }
            case ButtonPress:
                if (event.xbutton.button == Button1) { w->mouse_buttons[0] = true; w->mouse_buttons_pressed[0] = true; }
                else if (event.xbutton.button == Button3) { w->mouse_buttons[1] = true; w->mouse_buttons_pressed[1] = true; }
                else if (event.xbutton.button == Button2) { w->mouse_buttons[2] = true; w->mouse_buttons_pressed[2] = true; }
                else if (event.xbutton.button == Button4) w->mouse_scroll += 1.0f;
                else if (event.xbutton.button == Button5) w->mouse_scroll -= 1.0f;
                else if (event.xbutton.button == 8) { w->mouse_buttons[3] = true; w->mouse_buttons_pressed[3] = true; }  // Side back
                else if (event.xbutton.button == 9) { w->mouse_buttons[4] = true; w->mouse_buttons_pressed[4] = true; }  // Side forward
                break;
            case ButtonRelease:
                if (event.xbutton.button == Button1) w->mouse_buttons[0] = false;
                else if (event.xbutton.button == Button3) w->mouse_buttons[1] = false;
                else if (event.xbutton.button == Button2) w->mouse_buttons[2] = false;
                else if (event.xbutton.button == 8) w->mouse_buttons[3] = false;
                else if (event.xbutton.button == 9) w->mouse_buttons[4] = false;
                break;
            case MotionNotify:
                w->mouse_x = (float)event.xmotion.x;
                w->mouse_y = (float)event.xmotion.y;
                break;
            case ConfigureNotify:
                if (event.xconfigure.width != w->width ||
                    event.xconfigure.height != w->height) {
                    w->width = event.xconfigure.width;
                    w->height = event.xconfigure.height;
                    w->resized = true;
                }
                break;
            case ClientMessage:
                if ((Atom)event.xclient.data.l[0] == w->wm_delete)
                    w->should_close = true;
                break;
        }
    }

    // Re-center cursor when captured
    if (w->mouse_captured) {
        int cx = w->width / 2;
        int cy = w->height / 2;
        XWarpPointer(w->display, None, w->x_window, 0, 0, 0, 0, cx, cy);
        XFlush(w->display);
        w->prev_mouse_x = (float)cx;
        w->prev_mouse_y = (float)cy;
        w->mouse_x = (float)cx;
        w->mouse_y = (float)cy;
    }

    // Poll gamepads
    gamepad_poll();
}

int platform_window_width(PlatformWindow* w) { return w ? w->width : 0; }
int platform_window_height(PlatformWindow* w) { return w ? w->height : 0; }
bool platform_window_resized(PlatformWindow* w) { return w ? w->resized : false; }

// ---- EGL Surface Hooks ----

void* platform_native_display(PlatformWindow* w) {
    return w ? (void*)w->display : NULL;
}

void* platform_native_window(PlatformWindow* w) {
    return w ? (void*)(uintptr_t)w->x_window : NULL;
}

// ---- Keyboard ----

bool platform_is_key_down(PlatformWindow* w, int key) {
    if (!w || key < 0 || key >= AGILIS_MAX_KEYS) return false;
    return w->keys[key];
}

bool platform_key_pressed(PlatformWindow* w, int key) {
    if (!w || key < 0 || key >= AGILIS_MAX_KEYS) return false;
    return w->keys_pressed[key];
}

uint32_t platform_char_pressed(PlatformWindow* w) {
    return w ? w->char_pressed : 0;
}

// ---- Mouse ----

bool platform_is_mouse_button_down(PlatformWindow* w, int button) {
    if (!w || button < 0 || button >= AGILIS_MAX_MOUSE_BUTTONS) return false;
    return w->mouse_buttons[button];
}

bool platform_mouse_button_pressed(PlatformWindow* w, int button) {
    if (!w || button < 0 || button >= AGILIS_MAX_MOUSE_BUTTONS) return false;
    return w->mouse_buttons_pressed[button];
}

float platform_mouse_x(PlatformWindow* w) { return w ? w->mouse_x : 0; }
float platform_mouse_y(PlatformWindow* w) { return w ? w->mouse_y : 0; }
float platform_mouse_dx(PlatformWindow* w) { return w ? w->mouse_dx : 0; }
float platform_mouse_dy(PlatformWindow* w) { return w ? w->mouse_dy : 0; }
float platform_mouse_scroll(PlatformWindow* w) { return w ? w->mouse_scroll : 0; }

// ---- Cursor & Mouse Capture ----

void platform_show_cursor(PlatformWindow* w, bool visible) {
    if (!w || w->cursor_visible == visible) return;
    w->cursor_visible = visible;
    if (visible) {
        XUndefineCursor(w->display, w->x_window);
    } else {
        XDefineCursor(w->display, w->x_window, w->blank_cursor);
    }
    XFlush(w->display);
}

bool platform_is_cursor_visible(PlatformWindow* w) {
    return w ? w->cursor_visible : true;
}

void platform_set_mouse_captured(PlatformWindow* w, bool captured) {
    if (!w || w->mouse_captured == captured) return;
    w->mouse_captured = captured;
    if (captured) {
        // Hide cursor and grab pointer
        XDefineCursor(w->display, w->x_window, w->blank_cursor);
        XGrabPointer(w->display, w->x_window, True,
            ButtonPressMask | ButtonReleaseMask | PointerMotionMask,
            GrabModeAsync, GrabModeAsync, w->x_window, None, CurrentTime);
        // Center cursor
        int cx = w->width / 2;
        int cy = w->height / 2;
        XWarpPointer(w->display, None, w->x_window, 0, 0, 0, 0, cx, cy);
        XFlush(w->display);
        w->mouse_x = (float)cx;
        w->mouse_y = (float)cy;
        w->prev_mouse_x = w->mouse_x;
        w->prev_mouse_y = w->mouse_y;
        w->mouse_dx = 0;
        w->mouse_dy = 0;
    } else {
        // Release pointer
        XUngrabPointer(w->display, CurrentTime);
        if (w->cursor_visible) {
            XUndefineCursor(w->display, w->x_window);
        }
        XFlush(w->display);
    }
}

bool platform_is_mouse_captured(PlatformWindow* w) {
    return w ? w->mouse_captured : false;
}

// ---- Gamepad (Linux Joystick API) ----

bool platform_is_gamepad_available(int index) {
    if (index < 0 || index >= AGILIS_MAX_GAMEPADS) return false;
    gamepad_init();
    gamepad_try_open(index);
    return g_gamepads[index].fd >= 0;
}

bool platform_is_gamepad_button_down(int index, int button) {
    if (index < 0 || index >= AGILIS_MAX_GAMEPADS) return false;
    if (button < 0 || button >= MAX_GAMEPAD_BUTTONS) return false;
    if (g_gamepads[index].fd < 0) return false;
    return g_gamepads[index].buttons[button];
}

float platform_gamepad_axis(int index, int axis) {
    if (index < 0 || index >= AGILIS_MAX_GAMEPADS) return 0;
    if (axis < 0 || axis >= MAX_GAMEPAD_AXES) return 0;
    if (g_gamepads[index].fd < 0) return 0;
    return g_gamepads[index].axes[axis];
}

const char* platform_gamepad_name(int index) {
    if (index < 0 || index >= AGILIS_MAX_GAMEPADS) return NULL;
    if (g_gamepads[index].fd < 0) return NULL;
    return g_gamepads[index].name;
}

bool platform_gamepad_button_pressed(int index, int button) {
    if (index < 0 || index >= AGILIS_MAX_GAMEPADS) return false;
    if (button < 0 || button >= MAX_GAMEPAD_BUTTONS) return false;
    if (g_gamepads[index].fd < 0) return false;
    return g_gamepads[index].buttons_pressed[button];
}

void platform_gamepad_set_vibration(int index, float leftMotor, float rightMotor) {
    // Would require FF_RUMBLE ioctl on evdev — no-op for now
    (void)index;
    (void)leftMotor;
    (void)rightMotor;
}

// ---- Frame Timing ----

void platform_set_target_fps(PlatformWindow* w, int fps) {
    if (w) w->target_fps = fps;
}

void platform_set_vsync(PlatformWindow* w, bool enabled) {
    if (w) w->vsync = enabled;
}

// ---- Touch (stubs — not applicable on Linux) ----

int platform_touch_count(PlatformWindow* w) {
    (void)w;
    return 0;
}

PlatformTouch platform_touch_at(PlatformWindow* w, int index) {
    (void)w;
    (void)index;
    PlatformTouch t = {0};
    return t;
}

#endif // __linux__
